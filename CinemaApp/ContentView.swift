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

            // 1. Принудительный клик по координатам крестика (правый нижний угол)
            function clickCloseByCoordinates() {
                var w = window.innerWidth || document.documentElement.clientWidth;
                var h = window.innerHeight || document.documentElement.clientHeight;

                // Крестик находится примерно в 20-30px от правого края и 20-50px от нижнего края
                var checkPoints = [
                    { x: w - 25, y: h - 35 },
                    { x: w - 30, y: h - 40 },
                    { x: w - 20, y: h - 30 },
                    { x: w - 35, y: h - 45 }
                ];

                for (var i = 0; i < checkPoints.length; i++) {
                    var pt = checkPoints[i];
                    var el = document.elementFromPoint(pt.x, pt.y);
                    if (!el) continue;

                    // Если попали в сам крестик, его обертку или иконку
                    var txt = (el.textContent || '').trim();
                    var cls = (el.className || '').toString().toLowerCase();
                    var isX = ['×', '✕', '✖', 'x', 'х', 'X'].indexOf(txt) !== -1 || cls.indexOf('close') !== -1;

                    if (isX || el.tagName === 'SVG' || el.tagName === 'PATH' || el.tagName === 'BUTTON' || el.tagName === 'SPAN' || el.tagName === 'DIV') {
                        // Не кликаем, если под куполом оказался плеер
                        if (el.closest && el.closest('#player, .player, iframe[src*="kodik"], iframe[src*="alloha"]')) {
                            continue;
                        }

                        try {
                            var opts = { bubbles: true, cancelable: true, view: window, clientX: pt.x, clientY: pt.y };
                            el.dispatchEvent(new PointerEvent('pointerdown', opts));
                            el.dispatchEvent(new PointerEvent('pointerup', opts));
                            el.dispatchEvent(new MouseEvent('click', opts));
                            if (typeof el.click === 'function') el.click();
                        } catch(e) {}
                    }
                }
            }

            // 2. Сканирование и удаление фиксированных блоков внизу
            function sweepBottomOverlays() {
                var nodes = document.body ? document.body.querySelectorAll('*') : [];
                var h = window.innerHeight || document.documentElement.clientHeight;
                var w = window.innerWidth || document.documentElement.clientWidth;

                for (var i = 0; i < nodes.length; i++) {
                    var el = nodes[i];
                    if (!el || !el.getBoundingClientRect) continue;

                    // Пропускаем видеоплеер
                    if (el.querySelector && el.querySelector('video, iframe[src*="kodik"], iframe[src*="alloha"], iframe[src*="videocdn"]')) {
                        continue;
                    }
                    if (el.tagName === 'IFRAME' && (el.src.indexOf('kodik') !== -1 || el.src.indexOf('alloha') !== -1)) {
                        continue;
                    }

                    var st = window.getComputedStyle(el);
                    if (st.position === 'fixed' || st.position === 'sticky') {
                        var r = el.getBoundingClientRect();

                        // Условие: находится в самом низу и занимает значительную часть ширины
                        var isBottomFixed = (r.bottom >= h - 10) && (r.top > h - 300) && (r.height < 350) && (r.width > w * 0.4);

                        if (isBottomFixed) {
                            // Кликаем по крестику внутри
                            var closeButtons = el.querySelectorAll('button, span, div, a, svg');
                            for (var j = 0; j < closeButtons.length; j++) {
                                var b = closeButtons[j];
                                var bTxt = (b.textContent || '').trim();
                                var bRect = b.getBoundingClientRect();
                                if (['×', '✕', '✖', 'x', 'х', 'X'].indexOf(bTxt) !== -1 || (bRect.width > 0 && bRect.width < 50 && bRect.height < 50)) {
                                    try {
                                        b.click();
                                        b.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
                                    } catch(e) {}
                                }
                            }

                            // Полностью уничтожаем элемент
                            el.style.setProperty('display', 'none', 'important');
                            el.style.setProperty('visibility', 'hidden', 'important');
                            el.style.setProperty('opacity', '0', 'important');
                            el.style.setProperty('pointer-events', 'none', 'important');
                            if (el.parentNode) {
                                el.parentNode.removeChild(el);
                            }
                        }
                    }
                }
            }

            function runAll() {
                clickCloseByCoordinates();
                sweepBottomOverlays();
            }

            // Запускаем сразу и с интервалами
            runAll();

            if (document.readyState === 'complete' || document.readyState === 'interactive') {
                runAll();
            } else {
                document.addEventListener('DOMContentLoaded', runAll);
            }

            var observer = new MutationObserver(function() {
                runAll();
            });

            if (document.body) {
                observer.observe(document.body, { childList: true, subtree: true, attributes: true });
            }

            var delays = [100, 250, 500, 800, 1200, 1800, 2500, 3500, 5000, 7000];
            delays.forEach(function(d) { setTimeout(runAll, d); });

            window.addEventListener('scroll', runAll, { passive: true });
            window.addEventListener('resize', runAll, { passive: true });
        })();
        """
        
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
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
        
        let urlPatterns = [
            ".*pinco.*",
            ".*kysh.*",
            ".*promocode.*",
            ".*bahis.*",
            ".*kazanmak.*",
            ".*pincogames.*",
            ".*b5c1d2e8c9982e3b965a27ac72ru7284cc.*",
            ".*sticky-ad.*",
            ".*floor-banner.*",
            ".*mobile-bottom-ad.*"
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
        
        let identifier = "AdBlockRules_v9"
        
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: identifier,
            encodedContentRuleList: jsonString
        ) { (contentRuleList, error) in
            if let error = error {
                print("Ошибка компиляции правил блокировки: \(error.localizedDescription)")
            }
            if let contentRuleList = contentRuleList {
                controller.add(contentRuleList)
                print("Правила v9 загружены (\(rulesArray.count) шт.)")
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
