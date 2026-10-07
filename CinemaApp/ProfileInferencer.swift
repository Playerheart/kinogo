import Foundation
import WebKit

struct InferenceResult {
    let host: String
    let profile: SiteProfile
    let movieCount: Int
    let log: String
}

final class ProfileInferencer: NSObject {
    static let shared = ProfileInferencer()

    private var webView: WKWebView?
    private var completion: ((InferenceResult?) -> Void)?
    private var host: String = ""
    private var isDone = false
    private var diagLog: [String] = []

    private var urlQueue: [URL] = []
    private var currentIdx = 0
    private var currentPageLabel: String = ""
    private var enqueuedURLs: Set<String> = []

    private struct PageResult {
        let label: String
        let url: URL
        let profile: SiteProfile
        let count: Int
    }
    private var pageResults: [PageResult] = []

    private override init() {
        super.init()
    }

    private func setupWebViewIfNeeded() {
        guard webView == nil else { return }
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        wv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        self.webView = wv
    }

    func infer(host: String, completion: @escaping (InferenceResult?) -> Void) {
        DispatchQueue.main.async {
            self.setupWebViewIfNeeded()

            self.host = host
            self.completion = completion
            self.isDone = false
            self.diagLog = []
            self.pageResults = []
            self.enqueuedURLs = []

            let starts: [String] = ["filmy/", "serialy/", "novinki/"]
            var urls: [URL] = []
            for path in starts {
                if let u = URL(string: "https://\(host)/\(path)") {
                    urls.append(u)
                    self.enqueuedURLs.insert(u.absoluteString)
                }
            }
            self.urlQueue = urls
            self.currentIdx = 0

            self.log("Хост: \(host)")
            self.log("UA: десктопный Safari")
            self.log("Стартовые страницы: \(starts.joined(separator: ", "))")

            self.loadNextPage()

            DispatchQueue.main.asyncAfter(deadline: .now() + 180) { [weak self] in
                guard let self = self, !self.isDone else { return }
                self.finishFailure(reason: "Таймаут 180 секунд")
            }
        }
    }

    private func enqueue(_ url: URL, reason: String) {
        let key = url.absoluteString
        guard !enqueuedURLs.contains(key) else { return }
        enqueuedURLs.insert(key)
        urlQueue.append(url)
        log("  + \(reason): \(url.path)")
    }

    private func loadNextPage() {
        guard !isDone else { return }
        guard currentIdx < urlQueue.count else {
            finishAllPages()
            return
        }
        guard let webView = webView else {
            finishFailure(reason: "WebView потерян")
            return
        }
        let url = urlQueue[currentIdx]
        currentPageLabel = url.path.isEmpty ? "главная" : url.path
        log("── [\(currentIdx + 1)/\(urlQueue.count)] \(url.absoluteString)")
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
        let cb = completion
        completion = nil
        cb?(InferenceResult(host: host, profile: SiteProfile.default, movieCount: 0, log: logString()))
    }

    private func finishAllPages() {
        guard !isDone else { return }
        isDone = true

        guard let best = pageResults.max(by: { $0.count < $1.count }) else {
            log("❌ Ни одна страница не дала кандидатов")
            let cb = completion
            completion = nil
            cb?(InferenceResult(host: host, profile: SiteProfile.default, movieCount: 0, log: logString()))
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

        let cb = completion
        completion = nil
        cb?(InferenceResult(host: host, profile: best.profile, movieCount: best.count, log: logString()))
    }

    // MARK: - Анализ текущей страницы

    private func analyze() {
        guard !isDone, let webView = webView else { return }

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
            let paginationLinks = (dict["paginationLinks"] as? [String]) ?? []
            let currentURL = webView.url ?? URL(string: "https://\(self.host)/")!

            self.log("  Заголовок: \(pageTitle)")
            self.log("  Ссылок /NNN-slug.html: \(movieLinksCount)")
            self.log("  Ссылок пагинации: \(paginationLinks.count)")
            if !paginationLinks.isEmpty {
                let sample = paginationLinks.prefix(6).joined(separator: ", ")
                self.log("  Примеры: \(sample)")
            }

            // 1) Добавляем найденные ссылки пагинации
            for href in paginationLinks {
                guard let u = URL(string: href, relativeTo: currentURL)?.absoluteURL else { continue }
                self.enqueue(u, reason: "пагинация")
            }

            // 2) Fallback: если это top-level каталог и ссылки пагинации не нашлись,
            //    генерируем /page/2/..6/ вручную.
            let path = currentURL.path
            let isTopLevelCatalog = (path == "/filmy/" || path == "/serialy/" || path == "/novinki/")
            if isTopLevelCatalog && paginationLinks.isEmpty {
                self.log("  ⚠️ Ссылок пагинации нет — генерирую /page/2/../page/6/")
                let base = path.hasSuffix("/") ? String(path.dropLast()) : path  // /filmy
                for n in 2...6 {
                    if let u = URL(string: "https://\(self.host)\(base)/page/\(n)/") {
                        self.enqueue(u, reason: "page/\(n)/")
                    }
                }
            }

            guard let candidates = dict["candidates"] as? [[String: Any]], !candidates.isEmpty else {
                self.log("  Кандидатов нет — пропускаю страницу")
                self.currentIdx += 1
                self.loadNextPage()
                return
            }

            self.validateCandidates(candidates, pageURL: currentURL)
        }
    }

    private func validateCandidates(_ candidates: [[String: Any]], pageURL: URL) {
        var idx = 0
        var bestOnPage: (profile: SiteProfile, count: Int, cardClass: String)?

        func step() {
            if isDone { return }
            guard idx < candidates.count else {
                if let b = bestOnPage, b.count > 0 {
                    self.log("  ✅ .\(b.cardClass) → \(b.count)")
                    self.pageResults.append(PageResult(
                        label: self.currentPageLabel,
                        url: pageURL,
                        profile: b.profile,
                        count: b.count
                    ))
                    // Ранний выход: если на первой странице каталога поймали >= 50 — не идём дальше
                    if b.count >= 50 {
                        self.log("  Ранний выход (>= 50 карточек)")
                        self.finishAllPages()
                        return
                    }
                } else {
                    self.log("  ⚠️ Все кандидаты дали 0")
                }
                self.currentIdx += 1
                self.loadNextPage()
                return
            }

            let cand = candidates[idx]; idx += 1
            let profile = self.buildProfile(from: cand)
            let cardClass = (cand["cardClass"] as? String) ?? "?"
            let titleSel = (cand["titleSelector"] as? String) ?? ""
            let posterSel = (cand["posterSelector"] as? String) ?? ""
            let js = ExtractionScripts.catalog(profile: profile)

            guard let webView = self.webView else { return }
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

    // MARK: - JS: сбор кандидатов + пагинация

    private static let collectorJS = """
    (function(){
    var out = {
      url: location.href,
      title: document.title,
      movieLinksCount: 0,
      candidates: [],
      paginationLinks: []
    };

    // ---- Сбор ссылок на фильмы ----
    var movieLinks = [];
    var allLinks = document.querySelectorAll('a[href]');
    for (var i = 0; i < allLinks.length && i < 10000; i++) {
      var h = allLinks[i].getAttribute('href') || '';
      if (/\\d+-[a-z0-9\\-]+\\.html/i.test(h)) {
        movieLinks.push(allLinks[i]);
      }
    }
    out.movieLinksCount = movieLinks.length;

    // ---- Сбор ссылок пагинации ----
    var pagSet = {};
    function addPag(href) {
      if (!href) return;
      if (href.indexOf('javascript:') === 0) return;
      if (href === '#' || href.indexOf('#') === 0) return;
      pagSet[href] = true;
    }

    // 1) Ссылки в контейнерах пагинации
    try {
      var containers = document.querySelectorAll(
        '.navigation, .pagination, .pagenav, .pages, .navig, ' +
        '.pageNavigation, .module-pagination, .pagi, .pager, ' +
        '[class*="pagination"], [class*="pagenav"], [class*="page-nav"]'
      );
      for (var c = 0; c < containers.length; c++) {
        var ls = containers[c].querySelectorAll('a[href]');
        for (var l = 0; l < ls.length; l++) {
          addPag(ls[l].getAttribute('href'));
        }
      }
    } catch(e) {}

    // 2) Ссылки с /page/ или ?page=
    try {
      for (var i = 0; i < allLinks.length; i++) {
        var h = allLinks[i].getAttribute('href') || '';
        if (h.indexOf('/page/') !== -1 || h.indexOf('?page=') !== -1 || h.indexOf('&page=') !== -1) {
          addPag(h);
        }
      }
    } catch(e) {}

    // 3) Ссылки с числовым текстом (2, 3, 4, ...)
    try {
      for (var i = 0; i < allLinks.length; i++) {
        var t = (allLinks[i].textContent || '').trim();
        if (/^\\d{1,3}$/.test(t)) {
          addPag(allLinks[i].getAttribute('href'));
        }
      }
    } catch(e) {}

    for (var k in pagSet) {
      out.paginationLinks.push(k);
    }

    if (movieLinks.length < 3) return JSON.stringify(out);

    // ---- Кандидаты-карточки ----
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
        // без логирования
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
