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
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.6))
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
    
    private let targetURL = URL(string: "https://mix.kinogo.mu")!
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        if #available(iOS 10.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = []
        }
        
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // 1. Сначала компилируем правила блокировки
        setupAdBlockRules(for: config.userContentController) {
            // 2. И только ПОСЛЕ успешной компиляции загружаем сайт
            DispatchQueue.main.async {
                let request = URLRequest(url: targetURL)
                // webView будет доступен здесь
            }
        }
        
        // 2. УСИЛЕННЫЙ JAVASCRIPT ДЛЯ ВЫЧИЩЕНИЯ DOM
        let js = """
        (function() {
            window.open = function() { return null; };
            window.alert = function() { return; };
            window.confirm = function() { return false; };
            window.prompt = function() { return null; };
            
            function removeAds() {
                var style = document.createElement('style');
                style.innerHTML = `
                    [class*="ads"], [id*="ads"], [class*="banner"], [id*="banner"],
                    [class*="popup"], [class*="popunder"], [class*="overlay"],
                    .adsbygoogle, iframe[src*="ads"], iframe[src*="banner"],
                    iframe[src*="promo"], div[style*="z-index: 9999"],
                    div[style*="z-index: 99999"], a[href*="googlesyndication"],
                    a[href*="adservice"], .ad-container, .ad-wrapper,
                    iframe[src*="pincogames"], iframe[src*="pinco"], 
                    img[src*="pinco"], [href*="pinco"], [class*="pinco"],
                    [id*="pinco"], iframe[src*="bet"], iframe[src*="casino"],
                    img[src*="b5c1d2e8c9982e3b965a27ac72ru7284cc"],
                    iframe[src*="b5c1d2e8c9982e3b965a27ac72ru7284cc"],
                    [src*="pinco_banner"], [href*="pinco_banner"] {
                        display: none !important;
                        visibility: hidden !important;
                        opacity: 0 !important;
                        pointer-events: none !important;
                        height: 0 !important;
                        width: 0 !important;
                        position: absolute !important;
                        top: -9999px !important;
                    }
                `;
                document.head.appendChild(style);

                var scripts = document.getElementsByTagName('script');
                for (var i = scripts.length - 1; i >= 0; i--) {
                    var src = scripts[i].src;
                    if (src && (src.includes('ads') || src.includes('banner') || src.includes('pop') || src.includes('promo') || src.includes('pinco') || src.includes('b5c1d2e8c9982e3b965a27ac72ru7284cc'))) {
                        scripts[i].parentNode.removeChild(scripts[i]);
                    }
                }
            }

            removeAds();

            var observer = new MutationObserver(function(mutations) {
                removeAds();
            });
            observer.observe(document.documentElement, { childList: true, subtree: true });
        })();
        """
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = true
        
        // Загружаем сайт сразу после создания webView,
        // но с задержкой, чтобы правила успели примениться
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let request = URLRequest(url: targetURL)
            webView.load(request)
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // НЕ загружаем сайт здесь, чтобы не было повторных загрузок
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func setupAdBlockRules(for userContentController: WKUserContentController, completion: @escaping () -> Void) {
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
            let rule: [String: Any] = [
                "trigger": [
                    "url-filter": ".*",
                    "if-domain": ["*\(domain)"]
                ],
                "action": [
                    "type": "block"
                ]
            ]
            rulesArray.append(rule)
        }
        
        let specificBannerRule: [String: Any] = [
            "trigger": [
                "url-filter": ".*pinco_banner.*\\.gif"
            ],
            "action": [
                "type": "block"
            ]
        ]
        rulesArray.append(specificBannerRule)
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: rulesArray),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "AdBlockRules",
                encodedContentRuleList: jsonString
            ) { (contentRuleList, error) in
                if let error = error {
                    print("Ошибка компиляции правил блокировки: \(error.localizedDescription)")
                }
                if let contentRuleList = contentRuleList {
                    userContentController.add(contentRuleList)
                    print("Правила блокировки рекламы успешно загружены.")
                }
                // Сообщаем, что можно грузить сайт
                completion()
            }
        } else {
            completion()
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
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
