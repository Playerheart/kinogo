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
        
        // Снайперский кликер по крестику
        let js = """
        (function() {
            window.open = function() { return null; };
            window.alert = function() { return; };
            window.confirm = function() { return false; };
            
            function clickTheCross() {
                var h = window.innerHeight || document.documentElement.clientHeight;
                
                // Ищем все элементы, которые могут быть крестиком (кнопки, иконки, спаны)
                var possibleCrosses = document.querySelectorAll('div, span, button, a, svg, i');
                
                for (var i = 0; i < possibleCrosses.length; i++) {
                    var el = possibleCrosses[i];
                    
                    // Защита: никогда не кликаем по плееру
                    if (el.closest && el.closest('#player, .player, .vjs-control-bar')) continue;
                    
                    var rect = el.getBoundingClientRect();
                    
                    // Крестик со скриншота находится в нижней половине экрана и имеет небольшой размер (от 10 до 60 пикселей)
                    if (rect.top > (h * 0.5) && rect.width >= 10 && rect.width <= 60 && rect.height >= 10 && rect.height <= 60) {
                        
                        var txt = (el.textContent || '').trim().toLowerCase();
                        var cls = (el.className || '').toString().toLowerCase();
                        
                        // Признаки того, что это кнопка закрытия
                        var isCross = ['×', 'x', '✕', '✖', 'х'].indexOf(txt) !== -1 || 
                                      cls.indexOf('close') !== -1 || 
                                      el.tagName.toLowerCase() === 'svg';
                        
                        if (isCross) {
                            try {
                                // Нажимаем на него всеми доступными способами для надежности
                                if (typeof el.click === 'function') el.click();
                                
                                el.dispatchEvent(new Event('touchstart', { bubbles: true }));
                                el.dispatchEvent(new Event('touchend', { bubbles: true }));
                                el.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
                                
                            } catch(e) {}
                        }
                    }
                }
            }

            // Запускаем проверку каждую секунду. Как только баннер появится — скрипт его сразу "закроет".
            setInterval(clickTheCross, 1000);
            
            // Также проверяем при любой активности
            window.addEventListener('scroll', clickTheCross, { passive: true });
            document.addEventListener('DOMContentLoaded', clickTheCross);
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
        // Оставляем базовую блокировку левых доменов для скорости загрузки
        let blockedDomains = [
            "doubleclick.net", "googlesyndication.com", "adsystem.com", "adnxs.com", 
            "criteo.com", "taboola.com", "outbrain.com", "ads.yandex.ru", "an.yandex.ru",
            "b5c1d2e8c9982e3b965a27ac72ru7284cc.com", "pincogames.com", "pinco.com"
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
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: rulesArray),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        let identifier = "AdBlockRules_v15"
        
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: identifier,
            encodedContentRuleList: jsonString
        ) { (contentRuleList, error) in
            if let contentRuleList = contentRuleList {
                controller.add(contentRuleList)
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
                if self.parent.isLoading { self.retryLoad(webView: webView) }
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
                if parent.isLoading { DispatchQueue.main.async { self.parent.isLoading = false } }
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
