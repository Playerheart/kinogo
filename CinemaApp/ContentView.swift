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
    
    private let targetURL = URL(string: "https://mix.kinogo.mu")!
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        if #available(iOS 10.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = []
        }
        
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // JavaScript для очистки DOM от рекламы
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
        
        // Компилируем правила блокировки рекламы и только ПОСЛЕ этого грузим сайт.
        // Это исправляет баг с белым экраном при первом запуске.
        let targetURL = self.targetURL
        compileAdBlockRules(for: config.userContentController) {
            DispatchQueue.main.async {
                webView.load(URLRequest(url: targetURL))
            }
        }
        
        return webView
    }
    
    // Не перезагружаем сайт при обновлении SwiftUI
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func compileAdBlockRules(for controller: WKUserContentController, completion: @escaping () -> Void) {
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
        
        // Блокировка конкретного баннера pinco по URL
        let specificBannerRule: [String: Any] = [
            "trigger": [
                "url-filter": ".*pinco_banner.*\\.gif"
            ],
            "action": [
                "type": "block"
            ]
        ]
        rulesArray.append(specificBannerRule)
        
        // Блокировка любых .gif с рекламных CDN
        let gifBannerRule: [String: Any] = [
            "trigger": [
                "url-filter": ".*b5c1d2e8c9982e3b965a27ac72ru7284cc\\.com.*"
            ],
            "action": [
                "type": "block"
            ]
        ]
        rulesArray.append(gifBannerRule)
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: rulesArray),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            completion()
            return
        }
        
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "AdBlockRules",
            encodedContentRuleList: jsonString
        ) { (contentRuleList, error) in
            if let error = error {
                print("Ошибка компиляции правил блокировки: \(error.localizedDescription)")
            }
            if let contentRuleList = contentRuleList {
                controller.add(contentRuleList)
                print("Правила блокировки рекламы успешно загружены.")
            }
            // Загружаем сайт только после применения правил
            completion()
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if parent.isLoading {
                DispatchQueue.main.async {
                    self.parent.isLoading = false
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if parent.isLoading {
                DispatchQueue.main.async {
                    self.parent.isLoading = false
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if parent.isLoading {
                DispatchQueue.main.async {
                    self.parent.isLoading = false
                }
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
