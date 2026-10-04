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

            function isVisible(el) {
                if (!el || !el.getBoundingClientRect) return false;
                var r = el.getBoundingClientRect();
                if (r.width < 4 || r.height < 4) return false;
                var st = window.getComputedStyle(el);
                if (st.display === 'none' || st.visibility === 'hidden') return false;
                if (parseFloat(st.opacity) === 0) return false;
                return true;
            }

            function simulateClick(el) {
                try {
                    ['mousedown','mouseup','click'].forEach(function(t) {
                        el.dispatchEvent(new MouseEvent(t, { bubbles: true, cancelable: true, view: window }));
                    });
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
                    [src*="pincogames"], [src*="promocode"],
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
                    if (src && (src.includes('ads') || src.includes('banner') || src.includes('pop') ||
                                src.includes('promo') || src.includes('pinco') ||
                                src.includes('kysh') || src.includes('bahis') ||
                                src.includes('b5c1d2e8c9982e3b965a27ac72ru7284cc'))) {
                        scripts[i].parentNode.removeChild(scripts[i]);
                    }
                }
            }

            // Прячем <img>, которые не загрузились (заблокированы на уровне сети)
            function hideBrokenImages() {
                var imgs = document.querySelectorAll('img');
                for (var i = 0; i < imgs.length; i++) {
                    var img = imgs[i];
                    var src = (img.getAttribute('src') || '').toLowerCase();
                    var isAdSource = src.indexOf('pinco') !== -1 ||
                                     src.indexOf('kysh') !== -1 ||
                                     src.indexOf('b5c1d2e8c9982e3b965a27ac72ru7284cc') !== -1 ||
                                     src.indexOf('promocode') !== -1;
                    var isBroken = img.complete && img.naturalWidth === 0;
                    if (isAdSource || isBroken) {
                        img.style.display = 'none';
                        // Скрываем родителя, если он почти пустой
                        var p = img.parentElement;
                        var depth = 0;
                        while (p && depth < 4) {
                            var textLen = (p.textContent || '').trim().length;
                            var otherContent = p.querySelectorAll('img:not([style*="display: none"]), iframe, video, canvas').length;
                            if (textLen < 20 && otherContent === 0) {
                                p.style.display = 'none';
                            }
                            p = p.parentElement;
                            depth++;
                        }
                    }
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

            // Ищем крестики как текстовые узлы через TreeWalker — находит в любой вложенности
            function clickByTextClose() {
                if (!document.body) return;
                var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null);
                var targets = ['×','✕','✖','⨯','✗','X','x','Х','х','ⓧ','❌','❎','❌'];
                var node;
                while ((node = walker.nextNode())) {
                    var t = (node.nodeValue || '').trim();
                    if (t.length === 0 || t.length > 3) continue;
                    if (targets.indexOf(t) === -1) continue;
                    var el = node.parentElement;
                    if (!el) continue;
                    // Кликаем по самому кликабельному родителю
                    var clickable = el;
                    var depth = 0;
                    while (clickable && depth < 4) {
                        var st = window.getComputedStyle(clickable);
                        if (st.cursor === 'pointer' || clickable.tagName === 'BUTTON' || clickable.tagName === 'A' || clickable.onclick) {
                            break;
                        }
                        clickable = clickable.parentElement;
                        depth++;
                    }
                    var target = clickable || el;
                    if (isVisible(target)) {
                        simulateClick(target);
                        hideAncestorOverlay(target);
                    }
                }
            }

            // Ищем элементы по классам/атрибутам close
            function clickByClassClose() {
                var selectors = [
                    '[class*="close" i]', '[id*="close" i]',
                    '[class*="dismiss" i]', '[id*="dismiss" i]',
                    '[aria-label*="close" i]', '[aria-label*="закрыть" i]',
                    '[title*="close" i]', '[title*="закрыть" i]',
                    '[data-action*="close" i]', '[data-dismiss]',
                    '[class*="cerrar" i]', '[class*="schliessen" i]',
                    'svg[class*="close" i]', 'svg[class*="x" i]',
                    'button[class*="x" i]', 'a[class*="x" i]',
                    'button[aria-label*="x" i]'
                ];
                for (var s = 0; s < selectors.length; s++) {
                    try {
                        var list = document.querySelectorAll(selectors[s]);
                        for (var i = 0; i < list.length; i++) {
                            var el = list[i];
                            if (isVisible(el)) {
                                simulateClick(el);
                                hideAncestorOverlay(el);
                            }
                        }
                    } catch(e) {}
                }
            }

            // Ищем иконки-X, реализованные через SVG
            function clickSvgClose() {
                var svgs = document.querySelectorAll('svg');
                for (var i = 0; i < svgs.length; i++) {
                    var svg = svgs[i];
                    if (!isVisible(svg)) continue;
                    var r = svg.getBoundingClientRect();
                    // Крестик обычно квадратный и небольшой
                    if (r.width > 80 || r.height > 80) continue;
                    if (Math.abs(r.width - r.height) > 10) continue;
                    // Кликаем по SVG и по его родителю
                    simulateClick(svg);
                    if (svg.parentElement) simulateClick(svg.parentElement);
                    hideAncestorOverlay(svg);
                }
            }

            // Прячем пустые оверлеи с высоким z-index
            function hideEmptyOverlays() {
                var candidates = document.querySelectorAll('div, section, aside, span');
                for (var i = 0; i < candidates.length; i++) {
                    var el = candidates[i];
                    var st = window.getComputedStyle(el);
                    if (st.position !== 'fixed' && st.position !== 'absolute') continue;
                    var z = parseInt(st.zIndex) || 0;
                    if (z < 500) continue;
                    var r = el.getBoundingClientRect();
                    if (r.width < 50 || r.height < 50) continue;
                    // Если внутри только картинка/скрипт/крестик — прячем
                    var hasUsefulContent = el.querySelectorAll('video, iframe[src*="kodik"], iframe[src*="alloha"], iframe[src*="bazon"], iframe[src*="videocdn"]').length > 0;
                    if (hasUsefulContent) continue;
                    el.style.display = 'none';
                    el.style.pointerEvents = 'none';
                }
            }

            var isRunning = false;
            function runAll() {
                if (isRunning) return;
                isRunning = true;
                try {
                    injectStyle();
                    removeScripts();
                    hideBrokenImages();
                    clickByTextClose();
                    clickByClassClose();
                    clickSvgClose();
                    hideEmptyOverlays();
                } finally {
                    isRunning = false;
                }
            }

            runAll();

            var pending = false;
            function scheduleRun() {
                if (pending) return;
                pending = true;
                setTimeout(function() { pending = false; runAll(); }, 300);
            }

            try {
                var observer = new MutationObserver(scheduleRun);
                observer.observe(document.documentElement, { childList: true, subtree: true });
            } catch(e) {}

            var delays = [100, 300, 600, 1000, 2000, 4000, 8000, 15000, 30000];
            delays.forEach(function(d) {
                setTimeout(runAll, d);
            });
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
        
        // Домен + все поддомены: пишем два правила (exact и wildcard)
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
        
        // Явная блокировка любых рекламных баннеров pinco/kysh любых форматов
        let bannerPatterns = [
            ".*pinco_banner.*",
            ".*pinco.*\\.(jpg|jpeg|png|gif|webp|svg|mp4)",
            ".*kysh.*\\.(jpg|jpeg|png|gif|webp|svg|mp4)",
            ".*promocode.*\\.(jpg|jpeg|png|gif|webp|svg)",
            ".*bahis.*",
            ".*kazanmak.*"
        ]
        for pattern in bannerPatterns {
            rulesArray.append([
                "trigger": ["url-filter": pattern],
                "action": ["type": "block"]
            ])
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: rulesArray),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }
        
        // Меняем идентификатор при каждом изменении, чтобы не подтянулся старый кэш
        let identifier = "AdBlockRules_v3"
        
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: identifier,
            encodedContentRuleList: jsonString
        ) { (contentRuleList, error) in
            if let error = error {
                print("Ошибка компиляции правил блокировки: \(error.localizedDescription)")
            }
            if let contentRuleList = contentRuleList {
                controller.add(contentRuleList)
                print("Правила блокировки v3 загружены (\(rulesArray.count) правил).")
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
