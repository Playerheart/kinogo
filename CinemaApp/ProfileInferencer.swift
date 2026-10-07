import Foundation
import WebKit

struct InferenceResult {
    let host: String
    let profile: SiteProfile
    let movieCount: Int
    let log: String
}

@MainActor
final class ProfileInferencer: NSObject {
    static let shared = ProfileInferencer()

    private var webView: WKWebView!
    private var completion: ((InferenceResult?) -> Void)?
    private var host: String = ""
    private var isDone = false

    private override init() {
        super.init()
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        // Блокируем картинки и шрифты — быстрее грузится, а нам нужен только DOM.
        let blockHeavy: [String: Any] = [
            "trigger": ["url-filter": ".*", "resource-type": ["image", "font"]],
            "action": ["type": "block"]
        ]
        if let data = try? JSONSerialization.data(withJSONObject: [blockHeavy]),
           let json = String(data: data, encoding: .utf8) {
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "BlockHeavyInference_v1",
                encodedContentRuleList: json
            ) { list, _ in
                if let list = list { config.userContentController.add(list) }
            }
        }

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    }

    func infer(host: String, completion: @escaping (InferenceResult?) -> Void) {
        self.host = host
        self.completion = completion
        self.isDone = false
        guard let url = URL(string: "https://\(host)/") else {
            finish(with: nil); return
        }
        webView.stopLoading()
        webView.load(URLRequest(url: url))

        DispatchQueue.main.asyncAfter(deadline: .now() + 45) { [weak self] in
            self?.finish(with: nil)
        }
    }

    private func finish(with result: InferenceResult?) {
        guard !isDone else { return }
        isDone = true
        completion?(result)
        completion = nil
    }

    // MARK: - Анализ

    private func analyze() {
        guard !isDone else { return }
        webView.evaluateJavaScript(ProfileInferencer.collectorJS) { [weak self] result, _ in
            guard let self = self, !self.isDone else { return }
            guard let jsonStr = result as? String,
                  let data = jsonStr.data(using: .utf8),
                  let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let candidates = dict["candidates"] as? [[String: Any]],
                  !candidates.isEmpty
            else {
                self.finish(with: nil)
                return
            }
            let linksCount = (dict["movieLinksCount"] as? Int) ?? 0
            self.validateCandidates(candidates, movieLinksCount: linksCount)
        }
    }

    private func validateCandidates(_ candidates: [[String: Any]], movieLinksCount: Int) {
        var log = "Найдено ссылок на фильмы: \(movieLinksCount)\nКандидатов: \(candidates.count)\n\n"
        var best: (SiteProfile, Int, String)?
        var idx = 0

        func step() {
            if isDone { return }
            guard idx < candidates.count else {
                if let (profile, count, bestLog) = best {
                    let result = InferenceResult(
                        host: host, profile: profile,
                        movieCount: count, log: log + bestLog
                    )
                    finish(with: result)
                } else {
                    finish(with: nil)
                }
                return
            }

            let cand = candidates[idx]; idx += 1
            let profile = buildProfile(from: cand)
            let cardClass = (cand["cardClass"] as? String) ?? "?"
            let js = ExtractionScripts.catalog(profile: profile)

            webView.evaluateJavaScript(js) { [weak self] res, _ in
                guard let self = self, !self.isDone else { return }
                var count = 0
                if let s = res as? String,
                   let d = s.data(using: .utf8),
                   let arr = (try? JSONSerialization.jsonObject(with: d)) as? [[String: Any]] {
                    count = arr.filter { m in
                        let title = (m["title"] as? String) ?? ""
                        let url = (m["url"] as? String) ?? ""
                        return !title.isEmpty && !url.isEmpty
                    }.count
                }
                log += "  • .\(cardClass) → \(count) фильмов\n"
                if best == nil || count > best!.1 {
                    best = (profile, count, "\nЛучший: .\(cardClass) (\(count) фильмов)")
                }
                step()
            }
        }
        step()
    }

    private func buildProfile(from cand: [String: Any]) -> SiteProfile {
        var p = SiteProfile.default
        if let card = cand["cardClass"] as? String, !card.isEmpty {
            p.catalogCard = ".\(card)"
        }
        if let title = cand["titleSelector"] as? String, !title.isEmpty {
            p.catalogTitleLink = title
        }
        if let poster = cand["posterSelector"] as? String, !poster.isEmpty {
            p.catalogPosterImg = poster
        }
        if let rating = cand["ratingSelector"] as? String, !rating.isEmpty {
            p.catalogRating = rating
        }
        return p
    }

    // MARK: - JS: сбор allLinks[i кандидатов

    private static let collectorJS = """
    (function(){
    var out = { url: location.href, title: document.title, movieLinksCount: 0, candidates: [] };

    var movieLinks = [];
    var allLinks = document.querySelectorAll('a[href]');
    for (var i = 0; i < allLinks.length && i < 5000; i++) {
      var h =].getAttribute('href') || '';
      if (/\\d+-[a-z0-9\\-]+\\.html/i.test(h)) {
        movieLinks.push(allLinks[i]);
      }
    }
    out.movieLinksCount = movieLinks.length;
    if (movieLinks.length < 3) return JSON.stringify(out);

    var classVotes = {};
    for (var i = 0; i < Math.min(movieLinks.length, 30); i++) {
      var link = movieLinks[i];
      var node = link;
      var depth = 0;
      while (node && node !== document.body && depth < 6) {
        node = node.parentElement;
        if (!node) break;
        depth++;
        var cls = String(node.className || '');
        if (!cls) continue;
        var parts = cls.trim().split(/\\s+/);
        for (var p = 0; p < parts.length; p++) {
          var c = parts[p];
          if (c.length < 3) continue;
          if (!classVotes[c]) classVotes[c] = { count: 0, sample: null };
          classVotes[c].count++;
          if (classVotes[c].sample === null) classVotes[c].sample = node;
        }
      }
    }

    var arr = [];
    for (var k in classVotes) {
      var v = classVotes[k];
      if (v.count < 3) continue;
      if (!v.sample) continue;
      if (!v.sample.querySelector('img')) continue;
      arr.push({ cardClass: k, count: v.count, el: v.sample });
    }
    arr.sort(function(a,b){return b.count - a.count});
    arr = arr.slice(0, 6);

    function buildSelector(el) {
      if (!el) return '';
      var tag = el.tagName.toLowerCase();
      var cls = String(el.className || '').trim();
      if (!cls) return tag;
      var parts = cls.split(/\\s+/).filter(function(p){return p.length >= 3});
      if (parts.length === 0) return tag;
      parts.sort(function(a,b){return b.length - a.length});
      return tag + '.' + parts[0];
    }

    for (var i = 0; i < arr.length; i++) {
      var el = arr[i].el;
      var card = { cardClass: arr[i].cardClass, count: arr[i].count };

      var titleEl = null;
      var hEls = el.querySelectorAll('h1, h2, h3, h4');
      for (var h = 0; h < hEls.length; h++) {
        var a = hEls[h].querySelector('a');
        if (a && (a.textContent || '').trim().length > 2) { titleEl = a; break; }
      }
      if (!titleEl) {
        var aAll = el.querySelectorAll('a');
        for (var ai = 0; ai < aAll.length; ai++) {
          var txt = (aAll[ai].textContent || '').trim();
          if (txt.length > 2 && txt.length < 200) { titleEl = aAll[ai]; break; }
        }
      }
      card.titleSelector = titleEl ? buildSelector(titleEl) : '';
      card.titleSample = titleEl ? (titleEl.textContent || '').trim().substring(0, 80) : '';

      var img = el.querySelector('img');
      card.posterSelector = img ? buildSelector(img) : '';
      card.posterSample = img ? String(img.getAttribute('src') || img.getAttribute('data-src') || '').substring(0, 120) : '';

      var ratingEl = null;
      var all = el.querySelectorAll('*');
      for (var r = 0; r < all.length && r < 300; r++) {
        var t = (all[r].textContent || '').trim();
        if (/^\\d\\.\\d$/.test(t)) { ratingEl = all[r]; break; }
      }
      card.ratingSelector = ratingEl ? buildSelector(ratingEl) : '';
      card.ratingSample = ratingEl ? (ratingEl.textContent || '').trim() : '';

      out.candidates.push(card);
    }

    return JSON.stringify(out);
    })();
    """
}

extension ProfileInferencer: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !isDone else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.analyze()
        }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(with: nil)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(with: nil)
    }
}
