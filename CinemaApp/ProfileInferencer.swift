import Foundation
import WebKit

struct InferenceResult {
    let host: String
    let profile: SiteProfile
    let movieCount: Int   // 0 = провал, >0 = успех
    let log: String
}

@MainActor
final class ProfileInferencer: NSObject {
    static let shared = ProfileInferencer()

    private var webView: WKWebView!
    private var completion: ((InferenceResult?) -> Void)?
    private var host: String = ""
    private var isDone = false
    private var diagLog: [String] = []

    private override init() {
        super.init()
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        // Картинки НЕ блокируем — иначе lazy-load на сайте может не сработать,
        // и каталог будет пустым. Жертвуем скоростью ради надёжности.

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    }

    func infer(host: String, completion: @escaping (InferenceResult?) -> Void) {
        self.host = host
        self.completion = completion
        self.isDone = false
        self.diagLog = []

        guard let url = URL(string: "https://\(host)/") else {
            finishFailure(reason: "Неверный хост: \(host)")
            return
        }
        log("Начинаю загрузку \(url.absoluteString)")
        webView.stopLoading()
        webView.load(URLRequest(url: url))

        DispatchQueue.main.asyncAfter(deadline: .now() + 45) { [weak self] in
            guard let self = self, !self.isDone else { return }
            self.finishFailure(reason: "Таймаут 45 секунд")
        }
    }

    private func log(_ msg: String) {
        diagLog.append(msg)
        print("[ProfileInferencer] \(msg)")
    }

    private func logString() -> String {
        return diagLog.joined(separator: "\n")
    }

    private func finishFailure(reason: String) {
        guard !isDone else { return }
        isDone = true
        log("❌ \(reason)")
        let result = InferenceResult(
            host: host,
            profile: SiteProfile.default,
            movieCount: 0,
            log: logString()
        )
        completion?(result)
        completion = nil
    }

    private func finishSuccess(profile: SiteProfile, movieCount: Int, detail: String) {
        guard !isDone else { return }
        isDone = true
        log(detail)
        let result = InferenceResult(
            host: host,
            profile: profile,
            movieCount: movieCount,
            log: logString()
        )
        completion?(result)
        completion = nil
    }

    // MARK: - Анализ

    private func analyze() {
        guard !isDone else { return }
        log("Анализирую DOM…")

        webView.evaluateJavaScript(ProfileInferencer.collectorJS) { [weak self] result, error in
            guard let self = self, !self.isDone else { return }

            if let err = error {
                self.finishFailure(reason: "JS-ошибка: \(err.localizedDescription)")
                return
            }

            guard let jsonStr = result as? String else {
                self.finishFailure(reason: "JS вернул не строку: \(String(describing: result))")
                return
            }

            guard let data = jsonStr.data(using: .utf8),
                  let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                self.finishFailure(reason: "JSON не парсится. Первые 200 символов: \(String(jsonStr.prefix(200)))")
                return
            }

            let movieLinksCount = (dict["movieLinksCount"] as? Int) ?? 0
            let title = (dict["title"] as? String) ?? "?"
            let pageURL = (dict["url"] as? String) ?? "?"
            self.log("Финальный URL: \(pageURL)")
            self.log("Заголовок страницы: \(title)")
            self.log("Ссылок /NNN-slug.html: \(movieLinksCount)")

            guard let candidates = dict["candidates"] as? [[String: Any]], !candidates.isEmpty else {
                self.finishFailure(reason: "Не найдено кандидатов-карточек (ссылок на фильмы: \(movieLinksCount))")
                return
            }
            self.log("Кандидатов: \(candidates.count)")

            self.validateCandidates(candidates)
        }
    }

    private func validateCandidates(_ candidates: [[String: Any]]) {
        var idx = 0
        var best: (profile: SiteProfile, count: Int, cardClass: String)?

        func step() {
            if isDone { return }
            guard idx < candidates.count else {
                if let b = best, b.count > 0 {
                    self.finishSuccess(
                        profile: b.profile,
                        movieCount: b.count,
                        detail: "✅ Лучший кандидат: .\(b.cardClass) → \(b.count) фильмов"
                    )
                } else {
                    self.finishFailure(reason: "Ни один кандидат не дал валидных фильмов")
                }
                return
            }

            let cand = candidates[idx]; idx += 1
            let profile = buildProfile(from: cand)
            let cardClass = (cand["cardClass"] as? String) ?? "?"
            let titleSel = (cand["titleSelector"] as? String) ?? ""
            let posterSel = (cand["posterSelector"] as? String) ?? ""
            let js = ExtractionScripts.catalog(profile: profile)

            webView.evaluateJavaScript(js) { [weak self] res, _ in
                guard let self = self, !self.isDone else { return }
                var count = 0
                if let s = res as? String,
                   let d = s.data(using: .utf8),
                   let arr = (try? JSONSerialization.jsonObject(with: d)) as? [[String: Any]] {
                    count = arr.filter { m in
                        let t = (m["title"] as? String) ?? ""
                        let u = (m["url"] as? String) ?? ""
                        return !t.isEmpty && !u.isEmpty
                    }.count
                }
                self.log("  • card=.\(cardClass) title=\"\(titleSel)\" poster=\"\(posterSel)\" → \(count) фильмов")
                if best == nil || count > best!.count {
                    best = (profile, count, cardClass)
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

    // MARK: - JS: сбор кандидатов

    private static let collectorJS = """
    (function(){
    var out = { url: location.href, title: document.title, movieLinksCount: 0, candidates: [] };

    var movieLinks = [];
    var allLinks = document.querySelectorAll('a[href]');
    for (var i = 0; i < allLinks.length && i < 5000; i++) {
      var h = allLinks[i].getAttribute('href') || '';
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
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        log("→ Начало навигации")
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        log("→ Загрузка завершена: \(webView.url?.absoluteString ?? "?")")
        guard !isDone else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.analyze()
        }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finishFailure(reason: "Ошибка навигации: \(error.localizedDescription)")
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finishFailure(reason: "Ошибка provisional: \(error.localizedDescription)")
    }
}
