import SwiftUI
import WebKit

struct ContentView: View {
    @State private var downloadURL: URL?
    @State private var showingShareSheet = false
    
    var body: some View {
        WebView(downloadURL: $downloadURL, showingShareSheet: $showingShareSheet)
            .edgesIgnoringSafeArea(.all)
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
    
    private let targetURL = URL(string: "https://mix.kinogo.mu")!
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        if #available(iOS 10.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = []
        }
        
        // Разрешаем открывать окна из JS
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // 1. НАСТРОЙКА БЛОКИРОВКИ РЕКЛАМЫ НА УРОВНЕ СЕТИ
        setupAdBlockRules(for: config.userContentController)
        
        // 2. УСИЛЕННЫЙ JAVASCRIPT ДЛЯ ВЫЧИЩЕНИЯ DOM
        let js = """
        (function() {
            // Блокировка всплывающих окон и алертов
            window.open = function() { return null; };
            window.alert = function() { return; };
            window.confirm = function() { return false; };
            window.prompt = function() { return null; };
            
            // Функция для удаления рекламных элементов
            function removeAds() {
                // Скрываем всё, что похоже на рекламу
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
                    [id*="pinco"], iframe[src*="bet"], iframe[src*="casino"] {
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

                // Удаляем рекламные скрипты
                var scripts = document.getElementsByTagName('script');
                for (var i = scripts.length - 1; i >= 0; i--) {
                    var src = scripts[i].src;
                    if (src && (src.includes('ads') || src.includes('banner') || src.includes('pop') || src.includes('promo') || src.includes('pinco'))) {
                        scripts[i].parentNode.removeChild(scripts[i]);
                    }
                }
            }

            // Запускаем при загрузке
            removeAds();

            // Следим за динамическими изменениями (MutationObserver)
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
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: targetURL)
        uiView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Настройка правил блокировки на уровне сети
    private func setupAdBlockRules(for userContentController: WKUserContentController) {
        let adBlockRules = """
        [
            {
                "trigger": {"url-filter": ".*", "resource-type": ["script", "image", "style-sheet", "font", "media", "fetch", "websocket"]},
                "action": {"type": "block"}
            }
        ]
        """
        
        // Здесь мы перечисляем домены, которые нужно заблокировать
        let blockedDomains = [
            "doubleclick.net", "googlesyndication.com", "googleadservices.com",
            "adsystem.com", "adnxs.com", "criteo.com", "taboola.com", "outbrain.com",
            "pincogames.com", "pinco.com", "bet.com", "casino.com",
            "adservice.google.com", "ads.yahoo.com", "ads.yandex.ru",
            "an.yandex.ru", "adf.ly", "shorte.st", "linkbucks.com"
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
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: rulesArray),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "AdBlockRules",
                encodedContentRuleList: jsonString
            ) { (contentRuleList, error) in
                if let error = error {
                    print("Ошибка компиляции правил блокировки: \(error.localizedDescription)")
                    return
                }
                if let contentRuleList = contentRuleList {
                    userContentController.add(contentRuleList)
                    print("Правила блокировки рекламы успешно загружены.")
                }
            }
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            
            let urlString = url.absoluteString.lowercased()
            
            // Перехват ссылок на скачивание файлов
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
            
            // Блокировка переходов на внешние рекламные домены
            let allowedHosts = ["kinogo.mu", "mix.kinogo.mu", "kodik.info", "alloha.tv", "bazon.cc", "videocdn.tv"]
            let isAllowed = allowedHosts.contains { urlString.contains($0) }
            
            if navigationAction.navigationType == .linkActivated && !isAllowed {
                decisionHandler(.cancel)
                return
            }
            
            // Открытие ссылок target="_blank" в текущем окне
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
                decisionHandler(.cancel)
                return
            }
            
            decisionHandler(.allow)
        }
    }
}
