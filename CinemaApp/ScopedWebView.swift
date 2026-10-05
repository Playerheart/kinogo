import SwiftUI
import WebKit

struct ScopedWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    var onMovieTap: ((URL) -> Void)? = nil

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        if #available(iOS 10.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = []
        }
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        let blockRules = """
        [
            {"trigger": {"url-filter": ".*", "if-domain": ["*b5c1d2e8c9982e3b965a27ac72ru7284cc.com"]}, "action": {"type": "block"}},
            {"trigger": {"url-filter": ".*pinco.*"}, "action": {"type": "block"}},
            {"trigger": {"url-filter": ".*kysh.*"}, "action": {"type": "block"}},
            {"trigger": {"url-filter": ".*promocode.*"}, "action": {"type": "block"}},
            {"trigger": {"url-filter": ".*bahis.*"}, "action": {"type": "block"}},
            {"trigger": {"url-filter": ".*kazanmak.*"}, "action": {"type": "block"}},
            {"trigger": {"url-filter": ".*googlesyndication.*"}, "action": {"type": "block"}},
            {"trigger": {"url-filter": ".*doubleclick.*"}, "action": {"type": "block"}}
        ]
        """
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "ScopedBlock_v4",
            encodedContentRuleList: blockRules
        ) { list, _ in
            if let list = list { config.userContentController.add(list) }
        }

        let js = """
        (function() {
            var HIDE_ID = '__scoped_hide__';
            function ensureStyle() {
                if (document.getElementById(HIDE_ID)) return;
                var style = document.createElement('style');
                style.id = HIDE_ID;
                style.innerHTML = `
                    header, footer, .header, .footer, .nav, .top-menu, .main-menu,
                    .sidebar, .left-side, .right-side, aside,
                    #header, #footer, #nav, #sidebar,
                    .comments, #comments, .social, .share, .breadcrumbs, .breadcrumb,
                    .yellow-banner, [class*="yellow-banner"],
                    [class*="pinco" i], [class*="kysh" i],
                    [data-adblock-hidden="1"] {
                        display: none !important;
                        visibility: hidden !important;
                        height: 0 !important;
                        min-height: 0 !important;
                    }
                    html, body {
                        background: #000 !important; color: #fff !important;
                        padding: 0 !important; margin: 0 !important;
                        max-width: 100% !important; overflow-x: hidden !important;
                    }
                    body * { max-width: 100% !important; }
                    .content, .main, .page, .wrapper, .container,
                    #content, #main, .content-wrapper, .main-content {
                        padding: 6px !important; margin: 0 !important;
                        max-width: 100% !important; width: 100% !important;
                        background: transparent !important; box-sizing: border-box !important;
                    }
                `;
                document.head.appendChild(style);
            }

            var BAD_TEXTS = [
                'pinco', 'promocode', 'bahis yap',
                'алғашқы бәс', 'жениске жет', 'осында жениске',
                'скачай официальное мобильное', 'скачай мобильное приложение',
                'подпишись на kinogo', 'будь в курсе актуальных'
            ];

            function containsPlayer(el) {
                if (!el.querySelector) return false;
                return el.querySelector('video, iframe[src*="cinemar"], iframe[src*="kodik"], iframe[src*="alloha"]') !== null;
            }

            function hideByText() {
                var candidates = document.querySelectorAll('div, section, aside, ins, span');
                for (var i = candidates.length - 1; i >= 0; i--) {
                    var el = candidates[i];
                    if (el.getAttribute('data-adblock-hidden')) continue;
                    if (el.style && el.style.display === 'none') continue;
                    if (containsPlayer(el)) continue;
                    var text = (el.textContent || '').toLowerCase();
                    if (text.length < 5 || text.length > 800) continue;
                    for (var j = 0; j < BAD_TEXTS.length; j++) {
                        if (text.indexOf(BAD_TEXTS[j]) !== -1) {
                            var r = el.getBoundingClientRect();
                            if (r.height > 40 && r.height < 500 && r.width > 180) {
                                el.style.setProperty('display', 'none', 'important');
                                el.setAttribute('data-adblock-hidden', '1');
                            }
                            break;
                        }
                    }
                }
            }

            function hideByImage() {
                var imgs = document.querySelectorAll('img');
                for (var i = 0; i < imgs.length; i++) {
                    var img = imgs[i];
                    if (img.getAttribute('data-adblock-hidden')) continue;
                    var src = (img.src || img.getAttribute('data-src') || '').toLowerCase();
                    var isAd = src.indexOf('pinco') !== -1 || src.indexOf('kysh') !== -1 ||
                               src.indexOf('promocode') !== -1 || src.indexOf('bahis') !== -1 ||
                               src.indexOf('b5c1d2e8') !== -1 ||
                               (img.complete && img.naturalWidth === 0 && src.indexOf('poster') === -1);
                    if (!isAd) continue;
                    img.style.setProperty('display', 'none', 'important');
                    var p = img.parentElement;
                    var depth = 0;
                    while (p && depth < 5) {
                        if (p.getAttribute('data-adblock-hidden')) break;
                        if (p.tagName === 'A' && p.href && p.href.indexOf('.html') !== -1) break;
                        var pr = p.getBoundingClientRect();
                        if (pr.height > 40 && pr.height < 400 && pr.width > 150) {
                            p.style.setProperty('display', 'none', 'important');
                            p.setAttribute('data-adblock-hidden', '1');
                            break;
                        }
                        p = p.parentElement; depth++;
                    }
                }
            }

            var pending = false;
            function run() {
                if (pending) return;
                pending = true;
                setTimeout(function() {
                    pending = false;
                    ensureStyle();
                    hideByText();
                    hideByImage();
                }, 250);
            }
            run();
            try {
                var obs = new MutationObserver(run);
                obs.observe(document.documentElement, { childList: true, subtree: true });
            } catch(e) {}
            [100, 500, 1500, 3000, 6000, 12000].forEach(function(d){ setTimeout(run, d); });
        })();
        """
        let script = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        config.userContentController.addUserScript(script)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        context.coordinator.webView = webView
        context.coordinator.onMovieTap = onMovieTap
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url && context.coordinator.lastLoadedURL != url {
            context.coordinator.lastLoadedURL = url
            uiView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(isLoading: $isLoading) }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        weak var webView: WKWebView?
        let isLoading: Binding<Bool>
        var onMovieTap: ((URL) -> Void)?
        var lastLoadedURL: URL?

        init(isLoading: Binding<Bool>) { self.isLoading = isLoading }

        // Паттерн страницы фильма: /12345-slug.html или /film/12345-slug.html
        private func isMovieURL(_ url: URL) -> Bool {
            let s = url.absoluteString
            if s.contains("/filmy/") || s.contains("/v1new/") || s.contains("/serialy/") ||
               s.contains("/top-filmy/") || s.contains("/xfsearch/") { return false }
            let pattern = #"/\d+-[a-z0-9\-]+\.html"#
            return s.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow); return
            }
            if navigationAction.navigationType == .linkActivated, isMovieURL(url) {
                onMovieTap?(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                if isMovieURL(url) { onMovieTap?(url) }
                else { webView.load(navigationAction.request) }
            }
            return nil
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async { self.isLoading.wrappedValue = true }
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async { self.isLoading.wrappedValue = false }
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.isLoading.wrappedValue = false }
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.isLoading.wrappedValue = false }
        }
    }
}
