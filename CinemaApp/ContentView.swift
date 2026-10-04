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

            var clickCount = 0;      // Лимит: максимум 2 клика за страницу
            var isCoolingDown = false; // Пауза между кликами, чтобы не сбивать скролл

            function tryControlledClose() {
                if (clickCount >= 2 || isCoolingDown) return;

                var w = window.innerWidth || document.documentElement.clientWidth;
                var h = window.innerHeight || document.documentElement.clientHeight;

                var checkPoints = [
                    { x: w - 25, y: h - 35 },
                    { x: w - 30, y: h - 40 },
                    { x: w - 20, y: h - 30 }
                ];

                for (var i = 0; i < checkPoints.length; i++) {
                    var pt = checkPoints[i];
                    var el = document.elementFromPoint(pt.x, pt.y);
                    if (!el) continue;

                    // Не затрагиваем плеер
                    if (el.closest && el.closest('#player, .player, iframe[src*="kodik"], iframe[src*="alloha"]')) {
                        continue;
                    }

                    var txt = (el.textContent || '').trim();
                    var cls = (el.className || '').toString().toLowerCase();
                    var isX = ['×', '✕', '✖', 'x', 'х', 'X'].indexOf(txt) !== -1 || cls.indexOf('close') !== -1;

                    if (isX || el.tagName === 'SVG' || el.tagName === 'PATH' || el.tagName === 'BUTTON' || el.tagName === 'SPAN' || el.tagName === 'DIV') {
                        try {
                            var opts = { bubbles: true, cancelable: true, view: window, clientX: pt.x, clientY: pt.y };
                            el.dispatchEvent(new MouseEvent('click', opts));
                            if (typeof el.click === 'function') el.click();
                            
                            clickCount++;
                            isCoolingDown = true;

                            // Скрываем сам контейнер
                            var parentFixed = el.closest('div[style*="fixed"], div[style*="sticky"], .sticky-banner');
                            if (parentFixed) {
                                parentFixed.style.setProperty('display', 'none', 'important');
                            }

                            // Пауза 2 секунды перед тем, как разблокировать проверку на второй баннер
                            setTimeout(function() {
                                isCoolingDown = false;
                            }, 2000);

                            break;
                        } catch(e) {}
                    }
                }
            }

            // График точечных проверок (первая волна + проверка на второй баннер спустя паузу)
            var schedule = [300, 600, 1000, 2000, 3500, 5000, 7000];
            schedule.forEach(function(delay) {
                setTimeout(tryControlledClose, delay);
            });
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
        
        let identifier = "AdBlockRules_v11"
        
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: identifier,
            encodedContentRuleList: jsonString
        ) { (contentRuleList, error) in
            if let error = error {
                print("Ошибка компиляции правил блокировки: \(error.localizedDescription)")
            }
            if let contentRuleList = contentRuleList {
                controller.add(contentRuleList)
                print("Правила v11 загружены (\(rulesArray.count) шт.)")
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
