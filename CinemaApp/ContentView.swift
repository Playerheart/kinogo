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
        
        // JS скрипт, уничтожающий прилипающие нижние баннеры и кликающий крестики
        let js = """
        (function() {
            window.open = function() { return null; };
            window.alert = function() { return; };
            window.confirm = function() { return false; };
            window.prompt = function() { return null; };

            function killStickyBottomBanners() {
                var elements = document.querySelectorAll('div, section, aside, footer, p, iframe, a');
                var screenHeight = window.innerHeight || document.documentElement.clientHeight;
                var screenWidth = window.innerWidth || document.documentElement.clientWidth;

                for (var i = 0; i < elements.length; i++) {
                    var el = elements[i];
                    
                    // Защита: пропускаем видеоплеер
                    if (el.querySelector && el.querySelector('video, iframe[src*="kodik"], iframe[src*="alloha"], iframe[src*="bazon"], iframe[src*="videocdn"]')) {
                        continue;
                    }
                    if (el.tagName === 'IFRAME' && (el.src.indexOf('kodik') !== -1 || el.src.indexOf('alloha') !== -1 || el.src.indexOf('videocdn') !== -1)) {
                        continue;
                    }

                    var style = window.getComputedStyle(el);
                    var isFixedOrSticky = style.position === 'fixed' || style.position === 'sticky';

                    if (isFixedOrSticky) {
                        var rect = el.getBoundingClientRect();
                        
                        // Если элемент находится в нижней 25% части экрана и имеет высоту меньше 350px (типичный плавающий баннер)
                        var isAtBottom = (rect.bottom >= screenHeight - 50) && (rect.top > screenHeight * 0.5);
                        var isBannerSize = rect.height > 20 && rect.height < 350 && rect.width > (screenWidth * 0.5);

                        if (isAtBottom && isBannerSize) {
                            
                            // 1. Ищем внутри этого контейнера кнопку-крестик и кликаем по ней
                            var targets = el.querySelectorAll('*');
                            for (var j = 0; j < targets.length; j++) {
                                var child = targets[j];
                                var cText = (child.textContent || '').trim();
                                var cClass = (child.className || '').toString().toLowerCase();
                                var cRect = child.getBoundingClientRect();

                                var isXMark = ['×', '✕', '✖', 'x', 'х', 'X'].indexOf(cText) !== -1;
                                var isCloseClass = cClass.indexOf('close') !== -1 || cClass.indexOf('cross') !== -1;
                                var isSmallRoundBtn = cRect.width > 15 && cRect.width < 60 && cRect.height > 15 && cRect.height < 60;

                                if (isXMark || isCloseClass || isSmallRoundBtn) {
                                    try {
                                        child.click();
                                        child.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
                                        child.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true, cancelable: true, view: window }));
                                        child.dispatchEvent(new PointerEvent('pointerup', { bubbles: true, cancelable: true, view: window }));
                                    } catch(e) {}
                                }
                            }

                            // 2. Уничтожаем сам баннер из DOM структуры
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

            // Быстрый запуск и постоянное слежение
            killStickyBottomBanners();

            var observer = new MutationObserver(function() {
                killStickyBottomBanners();
            });

            function startObserver() {
                if (document.body) {
                    observer.observe(document.body, { childList: true, subtree: true, attributes: true });
                }
            }

            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', startObserver);
            } else {
                startObserver();
            }

            // Периодическая зачистка (на случай задержек скриптов рекламной сети)
            var timerIds = [100, 300, 500, 1000, 1500, 2500, 4000, 6000];
            timerIds.forEach(function(ms) {
                setTimeout(killStickyBottomBanners, ms);
            });

            window.addEventListener('scroll', killStickyBottomBanners, { passive: true });
            window.addEventListener('resize', killStickyBottomBanners, { passive: true });
        })();
        """
        
        // Внедряем скрипт сразу при старте загрузки документа
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
        
        let identifier = "AdBlockRules_v8"
        
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: identifier,
            encodedContentRuleList: jsonString
        ) { (contentRuleList, error) in
            if let error = error {
                print("Ошибка компиляции правил блокировки: \(error.localizedDescription)")
            }
            if let contentRuleList = contentRuleList {
                controller.add(contentRuleList)
                print("Правила v8 загружены (\(rulesArray.count) шт.)")
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
