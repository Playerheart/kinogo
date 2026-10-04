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
        
        // Внедряем единый глобальный стилизатор, блокирующий баннеры на уровне макета без кликов
        let js = """
        (function() {
            window.open = function() { return null; };
            window.alert = function() { return; };
            window.confirm = function() { return false; };
            window.prompt = function() { return null; };

            // Добавляем глобальный CSS, глушащий фиксированные нижние блоки
            var styleEl = document.createElement('style');
            styleEl.innerHTML = `
                div[style*="position: fixed"][style*="bottom: 0"],
                div[style*="position:fixed"][style*="bottom:0"],
                div[style*="position: fixed"][style*="bottom:0"],
                div[style*="position:fixed"][style*="bottom: 0"],
                [class*="sticky-banner"], [id*="sticky-banner"],
                [class*="bottom-ad"], [id*="bottom-ad"],
                [class*="floor-ad"], [id*="floor-ad"] {
                    display: none !important;
                    visibility: hidden !important;
                    opacity: 0 !important;
                    pointer-events: none !important;
                    height: 0 !important;
                }
            `;
            (document.head || document.documentElement).appendChild(styleEl);

            function purgeBottomBanners() {
                var nodes = document.querySelectorAll('body > div, body > iframe, body > section');
                var screenHeight = window.innerHeight || document.documentElement.clientHeight;

                for (var i = 0; i < nodes.length; i++) {
                    var el = nodes[i];
                    if (!el) continue;

                    // Защищаем контейнер плеера
                    if (el.querySelector && el.querySelector('video, iframe[src*="kodik"], iframe[src*="alloha"], iframe[src*="bazon"], iframe[src*="videocdn"]')) {
                        continue;
                    }
                    if (el.id === 'player' || el.className.indexOf('player') !== -1) {
                        continue;
                    }

                    var style = window.getComputedStyle(el);
                    var isFixed = style.position === 'fixed' || style.position === 'sticky';

                    if (isFixed) {
                        var rect = el.getBoundingClientRect();
                        // Если элемент прилип к нижней части экрана (bottom >= screenHeight - 20)
                        if (rect.bottom >= screenHeight - 30 && rect.top > screenHeight * 0.4) {
                            el.style.setProperty('display', 'none', 'important');
                            el.style.setProperty('pointer-events', 'none', 'important');
                            if (el.parentNode) {
                                el.parentNode.removeChild(el);
                            }
                        }
                    }
                }
            }

            // Безопасный наблюдатель за DOM без тапов и фокусов
            var observer = new MutationObserver(function() {
                purgeBottomBanners();
            });

            function start() {
                purgeBottomBanners();
                if (document.body) {
                    observer.observe(document.body, { childList: true, subtree: true, attributes: true });
                }
            }

            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', start);
            } else {
                start();
            }

            // Дополнительная проверка при взаимодействии (без кликов)
            window.addEventListener('scroll', purgeBottomBanners, { passive: true });
            window.addEventListener('touchend', function() {
                setTimeout(purgeBottomBanners, 100);
            }, { passive: true });
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
        
        let identifier = "AdBlockRules_v12"
        
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: identifier,
            encodedContentRuleList: jsonString
        ) { (contentRuleList, error) in
            if let error = error {
                print("Ошибка компиляции правил блокировки: \(error.localizedDescription)")
            }
            if let contentRuleList = contentRuleList {
                controller.add(contentRuleList)
                print("Правила v12 загружены (\(rulesArray.count) шт.)")
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
