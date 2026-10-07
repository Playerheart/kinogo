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
    private var diagLog: [String] = []

    // Очередь страниц для инференса: сначала каталоги, потом главная как fallback.
    private var urlQueue: [URL] = []
    private var currentIdx = 0
    private var currentPageLabel: String = ""

    private struct PageResult {
        let label: String
        let url: URL
        let profile: SiteProfile
        let count: Int
        let candidates: [[String: Any]]
    }
    private var pageResults: [PageResult] = []

    private override init() {
        super.init()
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    }

    func infer(host: String, completion: @escaping (InferenceResult?) -> Void) {
        self.host = host
        self.completion = completion
        self.isDone = false
        self.diagLog = []
        self.pageResults = []

        let candidates: [(String, String)] = [
            ("filmy/", "Фильмы"),
            ("movies/", "Фильмы (alt)"),
            ("films/", "Фильмы (alt2)"),
            ("serialy/", "Сериалы"),
            ("novinki/", "Новинки"),
            ("", "Главная")
        ]

        var urls: [URL] = []
        for (path, _) in candidates {
            if let u = URL(string: "https://\(host)/\(path)") {
                urls.append(u)
            }
        }
        self.urlQueue = urls
        self.currentIdx = 0

        log("Хост: \(host)")
        log("Буду проверять страницы: \(candidates.map { $0.0.isEmpty ? "(главная)" : $0.0 }.joined(separator: ", "))")

        loadNextPage()

        DispatchQueue.main.asyncAfter(deadline: .now() + 90) { [weak self] in
            guard let self = self, !self.isDone else { return }
            self.finishFailure(reason: "Таймаут 90 секунд")
        }
    }

    private func loadNextPage() {
        guard !isDone else { return }
        guard currentIdx < urlQueue.count else {
            finalize()
            return
        }
        let url = urlQueue[currentIdx]
        currentPageLabel = url.path.isEmpty ? "главная" : url.path
        log("── Страница \(currentIdx + 1)/\(urlQueue.count): \(url.absoluteString)")
        webView.stopLoading()
        webView.load(URLRequest(url: url))
    }

    private func log(_ msg: String) {
        diagLog.append(msg)
    }

    private func logString() -> String { diagLog.joined(separator: "\n") }

    private func finishFailure(reason: String) {
        guard !isDone else { return }
        isDone = true
        log("❌ \(reason)")
        completion?(InferenceResult(host: host, profile: SiteProfile.default, movieCount: 0, log: logString()))
        completion = nil
    }

    private func finalize() {
        guard !isDone else { return }
        isDone = true

        guard let best = pageResults.max(by: { $0.count < $1.count }) else {
            log("❌ Ни одна страница не дала кандидатов")
            completion?(InferenceResult(host: host, profile: SiteProfile.default, movieCount: 0, log: logString()))
            completion = nil
            return
        }

        log("")
        log("═══ Итог ═══")
        log("Лучшая страница: \(best.label) (\(best.count) карточек)")
        log("Профиль:")
        log("  card   = \(best.profile.catalogCard)")
        log("  title  = \(best.profile.catalogTitleLink)")
        log("  poster = \(best.profile.catalogPosterImg)")
        log("  rating = \(best.profile.catalogRating)")

        completion?(InferenceResult(host: host, profile: best.profile, movieCount: best.count, log: logString()))
        completion = nil
    }

    // MARK: - Анализ текущей страницы

    private func analyze() {
        guard !isDone else { return }
        log("  Анализирую DOM…")

        webView.evaluateJavaScript(ProfileInferencer.collectorJS) { [weak self] result, error in
            guard let self = self, !self.isDone else { return }

            if let err = error {
                self.log("  ⚠️ JS-ошибка: \(err.localizedDescription)")
                self.currentIdx += 1
                self.loadNextPage()
                return
            }

            guard let jsonStr = result as? String,
                  let data = jsonStr.data(using: .utf8),
                  let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                self.log("  ⚠️ JS вернул не JSON")
                self.currentIdx += 1
                self.loadNextPage()
                return
            }

            let movieLinksCount = (dict["movieLinksCount"] as? Int) ?? 0
            let pageTitle = (dict["title"] as? String) ?? "?"
            self.log("  Заголовок: \(pageTitle)")
            self.log("  Ссылок /NNN-slug.html: \(movieLinksCount)")

            guard let candidates = dict["candidates"] as? [[String: Any]], !candidates.isEmpty else {
                self.log("  Кандидатов нет — пропускаю страницу")
                self.currentIdx += 1
                self.loadNextPage()
                return
            }
            self.log("  Кандидатов: \(candidates.count)")

            self.validateCandidates(candidates, pageURL: self.webView.url ?? URL(string: "https://\(self.host)/")!)
        }
    }

    private func validateCandidates(_ candidates: [[String: Any]], pageURL: URL) {
        var idx = 0
        var bestOnPage: (profile: SiteProfile, count: Int, cardClass: String)?

        func step() {
            if isDone { return }
            guard idx < candidates.count else {
                if let b = bestOnPage, b.count > 0 {
                    self.log("  ✅ Лучший на этой странице: .\(b.cardClass) → \(b.count)")
                    self.pageResults.append(PageResult(
                        label: self.currentPageLabel,
                        url: pageURL,
                        profile: b.profile,
                        count: b.count,
                        candidates: candidates
                    ))
                    // Ранний выход: если нашли ≥50 карточек на первом каталоге — дальше смысла нет
                    if b.count >= 50 && self.currentIdx == 0 {
                        self.log("  Ранний выход (достаточно карточек)")
                        self.finalize()
                        return
                    }
                } else {
                    self.log("  ⚠️ Все кандидаты дали 0 фильмов")
                }
                self.currentIdx += 1
                self.loadNextPage()
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
                self.log("    • .\(cardClass)  t=\"\(titleSel)\"  p=\"\(posterSel)\" → \(count)")
                if bestOnPage == nil || count > bestOnPage!.count {
                    bestOnPage = (profile, count, cardClass)
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
        if let title = cand["titleSelector"] as? String, isRealSelector(title) {
            p.catalogTitleLink = title
        }
        if let poster = cand["posterSelector"] as? String, isRealSelector(poster) {
            p.catalogPosterImg = poster
        }
        if let rating = cand["ratingSelector"] as? String, isRealSelector(rating) {
            p.catalogRating = rating
        }
        return p
    }

    private func isRealSelector(_ s: String) -> Bool {
        if s.isEmpty { return false }
        return s.contains(".") || s.contains(" ") || s.contains(">") || s.contains("[")
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
    for (var i = 0; i < Math.min(movieLinks.length, 60); i++) {
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
    arr = arr.slice(0, 8);

    function classesOf(el) {
      var cls = String(el.className || '').trim();
      if (!cls) return [];
      return cls.split(/\\s+/).filter(function(p){return p.length >= 3});
    }

    function buildSelector(el) {
      if (!el) return '';
      var tag = el.tagName.toLowerCase();
      var parts = classesOf(el);
      if (parts.length > 0) {
        parts.sort(function(a,b){return b.length - a.length});
        return tag + '.' + parts[0];
      }
      var node = el.parentElement;
      var depth = 0;
      while (node && node !== document.body && depth < 4) {
        var pcls = classesOf(node);
        if (pcls.length > 0) {
          pcls.sort(function(a,b){return b.length - a.length});
          return node.tagName.toLowerCase() + '.' + pcls[0] + ' ' + tag;
        }
        node = node.parentElement;
        depth++;
      }
      return tag;
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
        // не логируем, чтобы не засорять
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !isDone else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            self?.analyze()
        }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        log("  ⚠️ Ошибка загрузки: \(error.localizedDescription)")
        currentIdx += 1
        loadNextPage()
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        log("  ⚠️ Ошибка provisional: \(error.localizedDescription)")
        currentIdx += 1
        loadNextPage()
    }
}
