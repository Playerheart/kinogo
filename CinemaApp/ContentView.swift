import SwiftUI
import WebKit

struct ContentView: View {
    @State private var downloadURL: URL?
    @State private var showingShareSheet = false
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            WebView(
                downloadURL: $downloadURL,
                showingShareSheet: $showingShareSheet,
                isLoading: $isLoading
            )
            .edgesIgnoringSafeArea(.all)
            
            if isLoading {
                ZStack {
                    Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
                    ProgressView()
                        .scaleEffect(1.6)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = downloadURL {
                ShareSheet(activityItems: [url])
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct WebView: UIViewRepresentable {
    @Binding var downloadURL: URL?
    @Binding var showingShareSheet: Bool
    @Binding var isLoading: Bool
    
    let targetURL = URL(string: "https://mix.kinogo.mu")!
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        if #available(iOS 10.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = []
        }
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        let js = """
        (function() {
            window.open = function() { return null; };
            window.alert = function() { return; };
            window.confirm = function() { return false; };
            window.prompt = function() { return null; };

            var HIDE_STYLE_ID = '__adblock_style__';
            var AD_URL_KEYWORDS = ['pinco', 'kysh', 'promocode', 'bahis', 'kazanmak',
                                   'b5c1d2e8c9982e3b965a27ac72ru7284cc', 'pincogames',
                                   'kasino', 'casino', 'betting', 'bet'];

            function urlIsAd(url) {
                if (!url) return false;
                url = url.toLowerCase();
                for (var i = 0; i < AD_URL_KEYWORDS.length; i++) {
                    if (url.indexOf(AD_URL_KEYWORDS[i]) !== -1) return true;
                }
                return false;
            }

            function isVisible(el) {
                if (!el || !el.getBoundingClientRect) return false;
                var r = el.getBoundingClientRect();
                if (r.width < 4 || r.height < 4) return false;
                var st = window.getComputedStyle(el);
                if (st.display === 'none' || st.visibility === 'hidden') return false;
                if (parseFloat(st.opacity) === 0) return false;
                return true;
            }

            // Агрессивный клик: pointer + touch + mouse + .click()
            function hardClick(el) {
                if (!el) return;
                try {
                    var opts = { bubbles: true, cancelable: true, view: window };
                    el.dispatchEvent(new PointerEvent('pointerdown', opts));
                    el.dispatchEvent(new PointerEvent('pointerup', opts));
                } catch(e) {}
                try {
                    var tOpts = { bubbles: true, cancelable: true, view: window };
                    el.dispatchEvent(new TouchEvent('touchstart', tOpts));
                    el.dispatchEvent(new TouchEvent('touchend', tOpts));
                } catch(e) {}
                try {
                    ['mousedown','mouseup','click'].forEach(function(t) {
                        el.dispatchEvent(new MouseEvent(t, { bubbles: true, cancelable: true, view: window }));
                    });
                } catch(e) {}
                try {
                    if (typeof el.click === 'function') el.click();
                } catch(e) {}
                // Обход onclick напрямую
                try {
                    if (el.onclick) el.onclick.call(el, new MouseEvent('click'));
                } catch(e) {}
            }

            function injectStyle() {
                if (document.getElementById(HIDE_STYLE_ID)) return;
                var style = document.createElement('style');
                style.id = HIDE_STYLE_ID;
                style.innerHTML = `
                    [class*="ads"], [id*="ads"], [class*="banner"], [id*="banner"],
                    [class*="popup"], [class*="popunder"], [class*="overlay"],
                    .adsbygoogle, iframe[src*="ads"], iframe[src*="banner"],
                    iframe[src*="promo"], a[href*="googlesyndication"],
                    a[href*="adservice"], .ad-container, .ad-wrapper,
                    iframe[src*="pincogames"], iframe[src*="pinco"],
                    img[src*="pinco"], [href*="pinco"], [class*="pinco"],
                    [id*="pinco"], iframe[src*="bet"], iframe[src*="casino"],
                    img[src*="b5c1d2e8c9982e3b965a27ac72ru7284cc"],
                    iframe[src*="b5c1d2e8c9982e3b965a27ac72ru7284cc"],
                    [src*="pinco_banner"], [href*="pinco_banner"],
                    [src*="kysh"], [class*="kysh"], [id*="kysh"],
                    [src*="promocode"], [class*="promocode"],
                    a[href*="bahis"], a[href*="kazanmak"], a[href*="kazan"] {
                        display: none !important;
                        visibility: hidden !important;
                        opacity: 0 !important;
                        pointer-events: none !important;
                        height: 0 !important;
                        width: 0 !important;
                        max-height: 0 !important;
                        max-width: 0 !important;
                        position: absolute !important;
                        top: -99999px !important;
                        left: -99999px !important;
                        z-index: -1 !important;
                    }
                `;
                document.head.appendChild(style);
            }

            function removeScripts() {
                var scripts = document.getElementsByTagName('script');
                for (var i = scripts.length - 1; i >= 0; i--) {
                    var src = scripts[i].src;
                    if (src && urlIsAd(src)) {
                        scripts[i].parentNode.removeChild(scripts[i]);
                    }
                }
            }

            // Скрываем все <img> и <iframe> с рекламными URL + их оверлеи
            function hideAdMedia() {
                var media = document.querySelectorAll('img, iframe, video, embed, object');
                for (var i = 0; i < media.length; i++) {
                    var el = media[i];
                    var src = (el.getAttribute('src') || el.getAttribute('data-src') || '').toLowerCase();
                    var isBroken = el.tagName === 'IMG' && el.complete && el.naturalWidth === 0;
                    if (urlIsAd(src) || isBroken) {
                        el.style.display = 'none';
                        el.style.visibility = 'hidden';
                        // Поднимаемся до родителя-оверлея и скрываем его целиком
                        var p = el.parentElement;
                        var depth = 0;
                        while (p && depth < 8) {
                            var st = window.getComputedStyle(p);
                            var r = p.getBoundingClientRect();
                            // Если родитель крупный и позиционированный — скрываем его
                            if ((st.position === 'fixed' || st.position === 'absolute') && r.width > 100 && r.height > 50) {
                                p.style.display = 'none';
                                p.style.visibility = 'hidden';
                                p.style.pointerEvents = 'none';
                                break;
                            }
                            p = p.parentElement;
                            depth++;
                        }
                    }
                }
            }

            // Ищем крестики ТОЛЬКО по тексту × ✕ X — быстрый путь
            function clickByTextClose() {
                if (!document.body) return;
                var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null);
                var targets = ['×','✕','✖','⨯','✗','X','x','Х','х','ⓧ','❌','❎'];
                var node;
                while ((node = walker.nextNode())) {
                    var t = (node.nodeValue || '').trim();
                    if (t.length === 0 || t.length > 3) continue;
                    if (targets.indexOf(t) === -1) continue;
                    var el = node.parentElement;
                    if (!el) continue;
                    var clickable = el;
                    var depth = 0;
                    while (clickable && depth < 5) {
                        var st = window.getComputedStyle(clickable);
                        if (st.cursor === 'pointer' || clickable.tagName === 'BUTTON' ||
                            clickable.tagName === 'A' || clickable.onclick ||
                            clickable.getAttribute('role') === 'button') break;
                        clickable = clickable.parentElement;
                        depth++;
                    }
                    var target = clickable || el;
                    if (isVisible(target)) {
                        hardClick(target);
                        hideAncestorOverlay(target);
                    }
                }
            }

            // Главный метод: ищем рекламу и в её правом верхнем углу — крестик
            function closeAdByProximity() {
                // 1. Находим все рекламные контейнеры
                var adContainers = [];
                var allMedia = document.querySelectorAll('img, iframe');
                for (var i = 0; i < allMedia.length; i++) {
                    var m = allMedia[i];
                    var src = (m.getAttribute('src') || '').toLowerCase();
                    if (!urlIsAd(src)) continue;
                    // Поднимаемся до позиционированного контейнера
                    var p = m.parentElement;
                    var depth = 0;
                    while (p && depth < 10) {
                        var st = window.getComputedStyle(p);
                        if (st.position === 'fixed' || st.position === 'absolute') {
                            var r = p.getBoundingClientRect();
                            if (r.width > 100 && r.height > 50 && r.top >= 0 && r.top < window.innerHeight) {
                                adContainers.push(p);
                            }
                            break;
                        }
                        p = p.parentElement;
                        depth++;
                    }
                }

                // 2. Для каждого рекламного контейнера ищем крестик в правом верхнем углу
                for (var c = 0; c < adContainers.length; c++) {
                    var container = adContainers[c];
                    var rect = container.getBoundingClientRect();
                    var searchArea = {
                        left: rect.right - 120,
                        right: rect.right + 20,
                        top: rect.top - 20,
                        bottom: rect.top + 120
                    };

                    // Обходим всё внутри родителя и ищем небольшой квадратный кликабельный элемент
                    var parent = container.parentElement || document.body;
                    var all = parent.querySelectorAll('*');
                    var bestBtn = null;
                    var bestScore = Infinity;
                    for (var j = 0; j < all.length; j++) {
                        var el = all[j];
                        if (!isVisible(el)) continue;
                        if (el.children.length > 3) continue; // крестик — лист или почти лист
                        var r = el.getBoundingClientRect();
                        // Крестик: небольшой (20–80px), почти квадратный
                        if (r.width < 15 || r.width > 100) continue;
                        if (r.height < 15 || r.height > 100) continue;
                        if (Math.abs(r.width - r.height) > 20) continue;
                        // В области правого верхнего угла рекламы
                        var cx = r.left + r.width / 2;
                        var cy = r.top + r.height / 2;
                        if (cx < searchArea.left || cx > searchArea.right) continue;
                        if (cy < searchArea.top || cy > searchArea.bottom) continue;
                        // Чем ближе к углу — тем лучше
                        var dist = Math.hypot(cx - rect.right, cy - rect.top);
                        if (dist < bestScore) {
                            bestScore = dist;
                            bestBtn = el;
                        }
                    }
                    if (bestBtn) {
                        hardClick(bestBtn);
                        // Иногда крестик внутри <button> или <a>
                        var wrap = bestBtn.closest('button, a, [role="button"]');
                        if (wrap && wrap !== bestBtn) hardClick(wrap);
                    }

                    // 3. В любом случае скрываем сам контейнер с рекламой
                    container.style.display = 'none';
                    container.style.visibility = 'hidden';
                    container.style.pointerEvents = 'none';
                }
            }

            function hideAncestorOverlay(el) {
                var p = el;
                var depth = 0;
                while (p && depth < 10) {
                    var st = window.getComputedStyle(p);
                    var z = parseInt(st.zIndex) || 0;
                    var pos = st.position;
                    if (pos === 'fixed' || (pos === 'absolute' && z > 100)) {
                        p.style.display = 'none';
                        p.style.visibility = 'hidden';
                        p.style.pointerEvents = 'none';
                        return true;
                    }
                    p = p.parentElement;
                    depth++;
                }
                return false;
            }

            function clickByClassClose() {
                var selectors = [
                    '[class*="close" i]', '[id*="close" i]',
                    '[class*="dismiss" i]', '[id*="dismiss" i]',
                    '[aria-label*="close" i]', '[aria-label*="закрыть" i]',
                    '[title*="close" i]', '[title*="закрыть" i]',
                    '[data-action*="close" i]', '[data-dismiss]'
                ];
                for (var s = 0; s < selectors.length; s++) {
                    try {
                        var list = document.querySelectorAll(selectors[s]);
                        for (var i = 0; i < list.length; i++) {
                            var el = list[i];
                            if (isVisible(el)) {
                                hardClick(el);
                                hideAncestorOverlay(el);
                            }
                        }
                    } catch(e) {}
                }
            }

            function clickSvgClose() {
                var svgs = document.querySelectorAll('svg');
                for (var i = 0; i < svgs.length; i++) {
                    var svg = svgs[i];
                    if (!isVisible(svg)) continue;
                    var r = svg.getBoundingClientRect();
                    if (r.width > 90 || r.height > 90) continue;
                    if (Math.abs(r.width - r.height) > 15) continue;
                    hardClick(svg);
                    if (svg.parentElement) hardClick(svg.parentElement);
                    hideAncestorOverlay(svg);
                }
            }

            var isRunning = false;
            function runAll() {
                if (isRunning) return;
                isRunning = true;
                try {
                    injectStyle();
                    removeScripts();
                    hideAdMedia();
                    clickByTextClose();
                    clickByClassClose();
                    clickSvgClose();
                    closeAdByProximity();
                } finally {
                    isRunning = false;
                }
            }

            runAll();

            var pending = false;
            function scheduleRun() {
                if (pending) return;
                pending = true;
                setTimeout(function() { pending = false; runAll(); }, 250);
            }

            try {
                var observer = new MutationObserver(scheduleRun);
                observer.observe(document.documentElement, { childList: true, subtree: true, attributes: true });
            } catch(e) {}

            // Частые прогоны в первые секунды, реже — дальше
            var delays = [80, 150, 300, 500, 800, 1200, 1800, 2500, 3500, 5000,
                          7000, 10000, 15000, 22000, 30000];
            delays.forEach(function(d) { setTimeout(runAll, d); });
        })();
        """
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)
        
        compileAdBlockRules(for: config.userContentController)
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = true
        
        context.coordinator.webView = webView
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.loadInitialURLIfNeeded(in: uiView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func compileAdBlockRules(for controller: WKUserContentController) {
        let blockedDomains = [
            "doubleclick.net", "googlesyndication.com", "googleadservices.com",
            "adsystem.com", "adnxs.com", "criteo.com", "taboola.com", "outbrain.com",
            "adservice.google.com", "ads.yahoo.com", "ads.yandex.ru", "an.yandex.ru",
            "adf.ly", "shorte.st", "linkbucks.com",
            "b5c1d2e8c9982e3b965a27ac72ru7284cc.com",
            "agl007.site", "ex-fs.net", "lordfilmserial.pics",
            "pincogames.com", "pinco.com", "bet.com", "casino.com"
        ]
        
        var rulesArray: [[String: Any]] = []
        
        for domain in blockedDomains {
            rulesArray.append([
                "trigger": ["url-filter": ".*", "if-domain": [domain]],
                "action": ["type": "block"]
            ])
            rulesArray.append([
                "trigger": ["url-filter": ".*", "if-domain": ["*.\(domain)"]],
                "action": ["type": "block"]
            ])
        }
        
        // URL-фильтры по ключевым словам — блокируют рекламу на любом домене
        let urlPatterns = [
            ".*pinco.*",
            ".*kysh.*",
            ".*promocode.*",
            ".*bahis.*",
            ".*kazanmak.*",
            ".*pincogames.*",
            ".*b5c1d2e8c9982e3b965a27ac72ru7284cc.*"
        ]
        for pattern in urlPatterns {
            rulesArray.append([
                "trigger": ["url-filter": pattern],
                "action": ["type": "block"]
            ])
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: rulesArray),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }
        
        let identifier = "AdBlockRules_v4"
        
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: identifier,
            encodedContentRuleList: jsonString
        ) { (contentRuleList, error) in
            if let error = error {
                print("Ошибка компиляции правил блокировки: \(error.localizedDescription)")
            }
            if let contentRuleList = contentRuleList {
                controller.add(contentRuleList)
                print("Правила v4 загружены (\(rulesArray.count) шт.)")
            }
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        weak var webView: WKWebView?
        private var didLoadInitial = false
        private var retryCount = 0
        private let maxRetries = 3
        private var loadTimeoutTimer: Timer?
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func loadInitialURLIfNeeded(in webView: WKWebView) {
            guard !didLoadInitial else { return }
            didLoadInitial = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self, weak webView] in
                guard let self = self, let webView = webView else { return }
                let request = URLRequest(url: self.parent.targetURL,
                                         cachePolicy: .reloadRevalidatingCacheData,
                                         timeoutInterval: 30)
                webView.load(request)
            }
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            loadTimeoutTimer?.invalidate()
            loadTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 12.0, repeats: false) { [weak self, weak webView] _ in
                guard let self = self, let webView = webView else { return }
                if self.parent.isLoading {
                    self.retryLoad(webView: webView)
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loadTimeoutTimer?.invalidate()
            retryCount = 0
            if parent.isLoading {
                DispatchQueue.main.async { self.parent.isLoading = false }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            loadTimeoutTimer?.invalidate()
            retryLoad(webView: webView)
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            loadTimeoutTimer?.invalidate()
            retryLoad(webView: webView)
        }
        
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            retryCount = 0
            webView.reload()
        }
        
        private func retryLoad(webView: WKWebView) {
            guard retryCount < maxRetries else {
                if parent.isLoading {
                    DispatchQueue.main.async { self.parent.isLoading = false }
                }
                return
            }
            retryCount += 1
            let delay = Double(retryCount) * 1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak webView] in
                guard let self = self, let webView = webView else { return }
                let request = URLRequest(url: self.parent.targetURL,
                                         cachePolicy: .reloadRevalidatingCacheData,
                                         timeoutInterval: 30)
                webView.load(request)
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            
            let urlString = url.absoluteString.lowercased()
            
            let downloadExtensions = [".mp4", ".mkv", ".avi", ".m3u8", ".mov", ".flv"]
            let isDownloadLink = downloadExtensions.contains { urlString.hasSuffix($0) } || urlString.contains("download") || urlString.contains("dl=")
            
            if isDownloadLink {
                DispatchQueue.main.async {
                    self.parent.downloadURL = url
                    self.parent.showingShareSheet = true
                }
                decisionHandler(.cancel)
                return
            }
            
            let allowedHosts = ["kinogo.mu", "mix.kinogo.mu", "kodik.info", "alloha.tv", "bazon.cc", "videocdn.tv"]
            let isAllowed = allowedHosts.contains { urlString.contains($0) }
            
            if navigationAction.navigationType == .linkActivated && !isAllowed {
                decisionHandler(.cancel)
                return
            }
            
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
                decisionHandler(.cancel)
                return
            }
            
            decisionHandler(.allow)
        }
    }
}
