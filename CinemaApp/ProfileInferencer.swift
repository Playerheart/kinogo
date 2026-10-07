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

    private var classVotes: [String: (hits: Int, avgCount: Int, best: SiteProfile)] = [:]

    private struct PageResult {
        let label: String
        let url: URL
        let profile: SiteProfile
        let count: Int
    }
    private var pageResults: [PageResult] = []

    private let maxPaginationPerStart = 3
    private var paginationDepthByPrefix: [String: Int] = [:]

    private var catalogProfile: SiteProfile?
    private var catalogMovieCount: Int = 0
    private var firstMovieURL: URL?

    private var isDetailStage = false

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
            self.classVotes = [:]
            self.paginationDepthByPrefix = [:]
            self.catalogProfile = nil
            self.catalogMovieCount = 0
            self.firstMovieURL = nil
            self.isDetailStage = false

            let starts: [String] = ["filmy/", "serialy/"]
            var urls: [URL] = []
            for path in starts {
                if let u = URL(string: "https://\(host)/\(path)") {
                    urls.append(u)
                    self.enqueuedURLs.insert(u.absoluteString)
                }
            }
            self.urlQueue = urls
            self.currentIdx = 0

            self.log("═══ Этап 1: каталог ═══")
            self.log("Хост: \(host)")
            self.log("UA: десктопный Safari")
            self.log("Стартовые страницы: \(starts.joined(separator: ", "))")

            self.loadNextPage()

            DispatchQueue.main.asyncAfter(deadline: .now() + 180) { [weak self] in
                guard let self = self, !self.isDone else { return }
                if self.catalogProfile != nil {
                    self.log("⚠️ Таймаут, но каталог уже определён — продолжаю")
                    self.startDetailStage()
                } else {
                    self.log("⚠️ Таймаут, финализирую по тому, что есть")
                    self.finishAllPages()
                }
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

        let catalogWinner: (profile: SiteProfile, count: Int, cardClass: String)? = {
            if let (cardClass, vote) = classVotes.max(by: { $0.value.hits < $1.value.hits }),
               vote.hits >= 2 {
                return (vote.best, vote.avgCount, cardClass)
            }
            if let best = pageResults.max(by: { $0.count < $1.count }) {
                let cardClass = best.profile.catalogCard
                    .replacingOccurrences(of: ".", with: "")
                    .components(separatedBy: " ").first ?? best.profile.catalogCard
                return (best.profile, best.count, cardClass)
            }
            return nil
        }()

        guard let winner = catalogWinner else {
            log("❌ Ни одна страница не дала кандидатов")
            isDone = true
            let cb = completion
            completion = nil
            cb?(InferenceResult(host: host, profile: SiteProfile.default, movieCount: 0, log: logString()))
            return
        }

        self.catalogProfile = winner.profile
        self.catalogMovieCount = winner.count

        log("")
        log("═══ Каталог определён ═══")
        log("Класс карточки: .\(winner.cardClass)")
        log("Среднее число карточек на странице: \(winner.count)")
        log("Профиль каталога:")
        log("  card   = \(winner.profile.catalogCard)")
        log("  title  = \(winner.profile.catalogTitleLink)")
        log("  poster = \(winner.profile.catalogPosterImg)")
        log("  rating = \(winner.profile.catalogRating)")

        startDetailStage()
    }

    private func startDetailStage() {
        guard !isDone else { return }
        isDetailStage = true

        log("")
        log("═══ Этап 2: детальная страница ═══")

        guard let movieURL = firstMovieURL else {
            log("⚠️ Не нашли URL фильма — пропускаю этап 2")
            finalizeAll()
            return
        }
        log("Открываю: \(movieURL.absoluteString)")

        guard let webView = webView else {
            log("⚠️ WebView потерян — пропускаю этап 2")
            finalizeAll()
            return
        }
        webView.stopLoading()
        webView.load(URLRequest(url: movieURL))
    }

    private func analyzeDetail() {
        guard !isDone, let webView = webView else { return }

        webView.evaluateJavaScript(ProfileInferencer.detailCollectorJS) { [weak self] result, error in
            guard let self = self, !self.isDone else { return }

            if let err = error {
                self.log("  ⚠️ JS-ошибка: \(err.localizedDescription)")
                self.finalizeAll()
                return
            }

            guard let jsonStr = result as? String,
                  let data = jsonStr.data(using: .utf8),
                  let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                self.log("  ⚠️ JS вернул не JSON: \(String(describing: result).prefix(200))")
                self.finalizeAll()
                return
            }

            if let e = dict["__err"] as? String, !e.isEmpty {
                self.log("  ⚠️ Внутренняя JS-ошибка: \(e)")
            }

            var profile = self.catalogProfile ?? SiteProfile.default

            if let h1 = dict["h1"] as? String, !h1.isEmpty {
                profile.detailH1 = h1
                self.log("  detailH1        = \(h1)")
            }
            if let poster = dict["poster"] as? String, !poster.isEmpty {
                profile.detailPosterImg = poster
                self.log("  detailPosterImg = \(poster)")
            }
            if let desc = dict["description"] as? String, !desc.isEmpty {
                profile.detailDescription = desc
                self.log("  detailDescription = \(desc)")
            }
            if let actors = dict["actorsContainer"] as? String, !actors.isEmpty {
                profile.detailActorsContainer = actors
                self.log("  detailActors      = \(actors)")
            }
            if let related = dict["related"] as? String, !related.isEmpty {
                profile.detailRelated = related
                self.log("  detailRelated     = \(related)")
            }
            if let info = dict["infoSpans"] as? String, !info.isEmpty {
                profile.detailInfoSpans = info
                self.log("  detailInfoSpans   = \(info)")
            }
            if let fdop = dict["fDop"] as? String, !fdop.isEmpty {
                profile.detailFDop = fdop
                self.log("  detailFDop        = \(fdop)")
            }
            if let tabs = dict["playersTabs"] as? String, !tabs.isEmpty {
                profile.detailPlayersTabs = tabs
                self.log("  detailPlayersTabs = \(tabs)")
            }
            if let cont = dict["playersContainer"] as? String, !cont.isEmpty {
                profile.detailPlayersContainer = cont
                self.log("  detailPlayersContainer = \(cont)")
            }

            self.catalogProfile = profile
            self.finalizeAll()
        }
    }

    private func finalizeAll() {
        guard !isDone else { return }
        isDone = true

        guard let profile = catalogProfile else {
            let cb = completion
            completion = nil
            cb?(InferenceResult(host: host, profile: SiteProfile.default, movieCount: 0, log: logString()))
            return
        }

        log("")
        log("═══ Итог ═══")
        log("Полный профиль:")
        log("  card   = \(profile.catalogCard)")
        log("  title  = \(profile.catalogTitleLink)")
        log("  poster = \(profile.catalogPosterImg)")
        log("  rating = \(profile.catalogRating)")
        log("  h1     = \(profile.detailH1)")
        log("  dPoster= \(profile.detailPosterImg)")
        log("  descr  = \(profile.detailDescription)")
        log("  actors = \(profile.detailActorsContainer)")
        log("  related= \(profile.detailRelated)")
        log("  info   = \(profile.detailInfoSpans)")
        log("  fDop   = \(profile.detailFDop)")
        log("  tabs   = \(profile.detailPlayersTabs)")
        log("  cont   = \(profile.detailPlayersContainer)")

        let cb = completion
        completion = nil
        cb?(InferenceResult(host: host, profile: profile, movieCount: catalogMovieCount, log: logString()))
    }

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
            let firstMovie = (dict["firstMovieURL"] as? String) ?? ""
            let currentURL = webView.url ?? URL(string: "https://\(self.host)/")!

            if self.firstMovieURL == nil, !firstMovie.isEmpty {
                if let u = URL(string: firstMovie, relativeTo: currentURL)?.absoluteURL {
                    self.firstMovieURL = u
                    self.log("  Первая карточка (для этапа 2): \(u.path)")
                }
            }

            self.log("  Заголовок: \(pageTitle)")
            self.log("  Ссылок /NNN-slug.html: \(movieLinksCount)")

            let prefix: String
            if currentURL.path.hasPrefix("/filmy/") { prefix = "filmy/" }
            else if currentURL.path.hasPrefix("/serialy/") { prefix = "serialy/" }
            else { prefix = "other/" }

            let depth = self.paginationDepthByPrefix[prefix] ?? 0
            if !paginationLinks.isEmpty && depth < self.maxPaginationPerStart {
                let nextPages = paginationLinks.prefix(self.maxPaginationPerStart)
                self.log("  Ссылок пагинации: \(paginationLinks.count) — беру первые \(nextPages.count)")
                for href in nextPages {
                    guard let u = URL(string: href, relativeTo: currentURL)?.absoluteURL else { continue }
                    self.enqueue(u, reason: "пагинация")
                    self.paginationDepthByPrefix[prefix] = (self.paginationDepthByPrefix[prefix] ?? 0) + 1
                }
            } else if !paginationLinks.isEmpty {
                self.log("  Пагинация: лимит для \(prefix) исчерпан (\(depth))")
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

                    let key = b.cardClass
                    if let existing = self.classVotes[key] {
                        let newHits = existing.hits + 1
                        let newAvg = (existing.avgCount * existing.hits + b.count) / newHits
                        self.classVotes[key] = (hits: newHits, avgCount: newAvg, best: existing.best)
                    } else {
                        self.classVotes[key] = (hits: 1, avgCount: b.count, best: b.profile)
                    }

                    if let v = self.classVotes[key], v.hits >= 3 && v.avgCount >= 5 {
                        self.log("  ⭐ Класс .\(key) подтверждён \(v.hits) раза, avg=\(v.avgCount). Финализация каталога.")
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

    // MARK: - JS: каталог

    private static let collectorJS = """
    (function(){
    var out = {
      url: location.href,
      title: document.title,
      movieLinksCount: 0,
      candidates: [],
      paginationLinks: [],
      firstMovieURL: ''
    };

    var allLinks = document.querySelectorAll('a[href]');

    var movieLinks = [];
    for (var i = 0; i < allLinks.length && i < 10000; i++) {
      var h = allLinks[i].getAttribute('href') || '';
      if (/\\d+-[a-z0-9\\-]+\\.html/i.test(h)) {
        movieLinks.push(allLinks[i]);
      }
    }
    out.movieLinksCount = movieLinks.length;
    if (movieLinks.length > 0) {
      out.firstMovieURL = movieLinks[0].getAttribute('href') || '';
    }

    var pagSet = {};
    function addPag(href) {
      if (!href) return;
      if (href.indexOf('javascript:') === 0) return;
      if (href === '#' || href.indexOf('#') === 0) return;
      pagSet[href] = true;
    }
    try {
      var containers = document.querySelectorAll(
        '.navigation, .pagination, .pagenav, .pages, .navig, ' +
        '.pageNavigation, .module-pagination, .pagi, .pager, ' +
        '[class*="pagination"], [class*="pagenav"], [class*="page-nav"], [class*="pagi"]'
      );
      for (var c = 0; c < containers.length; c++) {
        var ls = containers[c].querySelectorAll('a[href]');
        for (var l = 0; l < ls.length; l++) {
          addPag(ls[l].getAttribute('href'));
        }
      }
    } catch(e) {}
    try {
      for (var i = 0; i < allLinks.length; i++) {
        var h = allLinks[i].getAttribute('href') || '';
        if (/\\/page\\/\\d+\\/?/.test(h) || h.indexOf('?page=') !== -1 || h.indexOf('&page=') !== -1) {
          addPag(h);
        }
      }
    } catch(e) {}
    try {
      for (var i = 0; i < allLinks.length; i++) {
        var t = (allLinks[i].textContent || '').trim();
        if (/^\\d{1,4}$/.test(t)) {
          addPag(allLinks[i].getAttribute('href'));
        }
      }
    } catch(e) {}

    for (var k in pagSet) {
      out.paginationLinks.push(k);
    }

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

    // MARK: - JS: детальная (максимально защищённый)

    private static let detailCollectorJS = """
    (function(){
    var out = {
      url: location.href,
      title: document.title,
      h1: '',
      poster: '',
      description: '',
      related: '',
      actorsContainer: '',
      infoSpans: '',
      fDop: '',
      playersTabs: '',
      playersContainer: '',
      __err: ''
    };

    function safe(fn, tag) {
      try { return fn(); } catch(e) { out.__err = (out.__err ? out.__err + '; ' : '') + tag + ': ' + (e && e.message ? e.message : String(e)); return null; }
    }

    function classesOf(el) {
      try {
        var cls = String(el.className || '').trim();
        if (!cls) return [];
        return cls.split(/\\s+/).filter(function(p){return p && p.length >= 3});
      } catch(e) { return []; }
    }

    function buildSelector(el) {
      if (!el) return '';
      try {
        var tag = el.tagName ? el.tagName.toLowerCase() : '';
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
      } catch(e) { return ''; }
    }

    // H1
    safe(function(){
      var h1 = document.querySelector('h1');
      if (h1) out.h1 = buildSelector(h1);
    }, 'h1');

    // Poster — самый большой <img>, не data:, не dot.gif, размер >= 100
    safe(function(){
      var bestImg = null, bestArea = 0;
      var imgs = document.querySelectorAll('img');
      for (var i = 0; i < imgs.length; i++) {
        var im = imgs[i];
        var w = 0, h = 0;
        try { w = im.naturalWidth || im.clientWidth || 0; } catch(e) {}
        try { h = im.naturalHeight || im.clientHeight || 0; } catch(e) {}
        var src = '';
        try { src = im.getAttribute('src') || im.getAttribute('data-src') || ''; } catch(e) {}
        if (!src || src.indexOf('dot.gif') !== -1 || src.indexOf('data:') === 0) continue;
        if (w < 100 && h < 100) continue;
        var area = w * h;
        if (area > bestArea) { bestArea = area; bestImg = im; }
      }
      if (bestImg) out.poster = buildSelector(bestImg);
    }, 'poster');

    // Description — самый длинный текстовый блок, не в sidebar/nav/footer
    safe(function(){
      function isInsideNoise(el) {
        var node = el;
        var depth = 0;
        while (node && node !== document.body && depth < 8) {
          var tag = node.tagName ? node.tagName.toLowerCase() : '';
          if (tag === 'nav' || tag === 'footer' || tag === 'aside' || tag === 'script' || tag === 'style') return true;
          var cls = '';
          try { cls = String(node.className || '').toLowerCase(); } catch(e) {}
          if (cls.indexOf('sidebar') !== -1 || cls.indexOf('footer') !== -1 ||
              cls.indexOf('menu') !== -1 || cls.indexOf('nav') !== -1) return true;
          node = node.parentElement;
          depth++;
        }
        return false;
      }
      var bestDesc = null, bestLen = 0;
      var cands = document.querySelectorAll('div, p, article, section');
      for (var i = 0; i < cands.length; i++) {
        var el = cands[i];
        var fullText = '';
        try { fullText = (el.textContent || '').trim(); } catch(e) { continue; }
        if (fullText.length < 200) continue;
        if (fullText.length > 5000) continue;
        if (isInsideNoise(el)) continue;
        var cls = '';
        try { cls = String(el.className || '').toLowerCase(); } catch(e) {}
        var score = fullText.length;
        if (cls.indexOf('descr') !== -1 || cls.indexOf('filmdescr') !== -1) score += 5000;
        if (score > bestLen) { bestLen = score; bestDesc = el; }
      }
      if (bestDesc) out.description = buildSelector(bestDesc);
    }, 'description');

    // Actors / infoSpans / fDop — обходим <b>/<strong>
    safe(function(){
      var allB = document.querySelectorAll('b, strong');
      var infoLabels = ['год выпуска', 'страна', 'жанр'];
      var fDopLabels = ['качество', 'длительность', 'перевод', 'озвучка'];
      var actorsFound = false;
      var infoFound = false;
      var fDopFound = false;

      for (var i = 0; i < allB.length; i++) {
        var t = '';
        try { t = (allB[i].textContent || '').replace(/\\s*:\\s*$/, '').toLowerCase().trim(); } catch(e) { continue; }
        if (!t) continue;

        if (!actorsFound && (t === 'актеры' || t === 'в ролях')) {
          var container = allB[i].parentElement;
          if (container) {
            out.actorsContainer = buildSelector(container);
            actorsFound = true;
          }
        }

        if (!infoFound && infoLabels.indexOf(t) !== -1) {
          var c2 = allB[i].parentElement;
          if (c2) {
            var parent = c2.parentElement;
            if (parent) out.infoSpans = buildSelector(parent) + ' > ' + buildSelector(c2);
            else out.infoSpans = buildSelector(c2);
            infoFound = true;
          }
        }

        if (!fDopFound && fDopLabels.indexOf(t) !== -1) {
          var c3 = allB[i].parentElement;
          if (c3) {
            var parent2 = c3.parentElement;
            if (parent2) out.fDop = buildSelector(parent2) + ' > ' + buildSelector(c3);
            else out.fDop = buildSelector(c3);
            fDopFound = true;
          }
        }

        if (actorsFound && infoFound && fDopFound) break;
      }
    }, 'bLabels');

    // playersTabs — первый [data-src]
    safe(function(){
      var tabs = document.querySelectorAll('[data-src]');
      if (tabs.length > 0) {
        out.playersTabs = buildSelector(tabs[0]);
      }
    }, 'tabs');

    // playersContainer — iframe с известным хостом плеера
    safe(function(){
      var ifr = document.querySelectorAll('iframe');
      for (var i = 0; i < ifr.length; i++) {
        var src = '';
        try { src = (ifr[i].getAttribute('src') || '').toLowerCase(); } catch(e) { continue; }
        if (src.indexOf('cinemar') !== -1 || src.indexOf('kodik') !== -1 ||
            src.indexOf('alloha') !== -1 || src.indexOf('videocdn') !== -1 ||
            src.indexOf('bazon') !== -1 || src.indexOf('sibnet') !== -1) {
          out.playersContainer = buildSelector(ifr[i]);
          break;
        }
      }
    }, 'iframe');

    // Related — контейнер с наибольшим числом ссылок /NNN-slug.html
    safe(function(){
      var relMap = {};
      var allLinks = document.querySelectorAll('a[href]');
      for (var i = 0; i < allLinks.length; i++) {
        var h = '';
        try { h = allLinks[i].getAttribute('href') || ''; } catch(e) { continue; }
        if (!/\\d+-[a-z0-9\\-]+\\.html/i.test(h)) continue;
        var node = allLinks[i].parentElement;
        var depth = 0;
        while (node && node !== document.body && depth < 5) {
          if (!relMap[node]) relMap[node] = 0;
          relMap[node]++;
          node = node.parentElement;
          depth++;
        }
      }
      var bestRel = null, bestRelCount = 0;
      for (var k in relMap) {
        if (relMap[k] > bestRelCount && relMap[k] >= 3) {
          bestRelCount = relMap[k];
          bestRel = k;
        }
      }
      if (bestRel) out.related = buildSelector(bestRel) + ' a';
    }, 'related');

    return JSON.stringify(out);
    })();
    """
}

extension ProfileInferencer: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !isDone else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            guard let self = self, !self.isDone else { return }
            if self.isDetailStage {
                self.analyzeDetail()
            } else {
                self.analyze()
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        log("  ⚠️ Ошибка загрузки: \(error.localizedDescription)")
        if isDetailStage {
            finalizeAll()
        } else {
            currentIdx += 1
            loadNextPage()
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        log("  ⚠️ Ошибка provisional: \(error.localizedDescription)")
        if isDetailStage {
            finalizeAll()
        } else {
            currentIdx += 1
            loadNextPage()
        }
    }
}
