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
        
        // НАСТРОЙКА БЛОКИРОВКИ РЕКЛАМЫ
        let js = """
        (function() {
            // 1. Блокировка всплывающих окон
            window.open = function() { return null; };
            window.alert = function() { return; };
            window.confirm = function() { return false; };
            window.prompt = function() { return null; };
            
            // 2. Скрытие рекламных блоков через CSS
            var style = document.createElement('style');
            style.innerHTML = `
                [class*="ads"], [id*="ads"], [class*="banner"], [id*="banner"],
                [class*="popup"], [class*="popunder"], [class*="overlay"],
                .adsbygoogle, iframe[src*="ads"], iframe[src*="banner"],
                iframe[src*="promo"], div[style*="z-index: 9999"],
                div[style*="z-index: 99999"], a[href*="googlesyndication"],
                a[href*="adservice"], .ad-container, .ad-wrapper {
                    display: none !important;
                    visibility: hidden !important;
                    opacity: 0 !important;
                    pointer-events: none !important;
                    height: 0 !important;
                    width: 0 !important;
                }
            `;
            document.head.appendChild(style);
            
            // 3. Удаление рекламных скриптов
            var scripts = document.getElementsByTagName('script');
            for (var i = scripts.length - 1; i >= 0; i--) {
                var src = scripts[i].src;
                if (src && (src.includes('ads') || src.includes('banner') || src.includes('pop') || src.includes('promo'))) {
                    scripts[i].parentNode.removeChild(scripts[i]);
                }
            }
        })();
        """
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = true
        
        // Отключаем "умную" проверку ссылок, чтобы не блокировались полезные скрипты
        webView.configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: targetURL)
        uiView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
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
            
            // 1. Перехват ссылок на скачивание файлов
            if urlString.hasSuffix(".mp4") || urlString.hasSuffix(".mkv") || urlString.hasSuffix(".avi") || urlString.hasSuffix(".m3u8") {
                DispatchQueue.main.async {
                    self.parent.downloadURL = url
                    self.parent.showingShareSheet = true
                }
                decisionHandler(.cancel)
                return
            }
            
            // 2. Блокировка переходов на внешние рекламные домены
            let allowedHosts = ["kinogo.mu", "mix.kinogo.mu", "kodik.info", "alloha.tv", "bazon.cc", "videocdn.tv"]
            let isAllowed = allowedHosts.contains { urlString.contains($0) }
            
            if navigationAction.navigationType == .linkActivated && !isAllowed {
                // Если ссылка ведет не на киносайт и не на плеер, отменяем переход
                // (это защита от случайного тыка по рекламе)
                decisionHandler(.cancel)
                return
            }
            
            // 3. Открытие ссылок target="_blank" в текущем окне
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
                decisionHandler(.cancel)
                return
            }
            
            decisionHandler(.allow)
        }
        
        // Обработка ошибок загрузки
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("Ошибка загрузки: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("Ошибка provisional загрузки: \(error.localizedDescription)")
        }
    }
}
