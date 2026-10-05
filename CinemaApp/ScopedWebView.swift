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
            {"trigger": {"url-filter": ".*", "if-domain": ["*agl010.pro"]}, "action": {"type": "block"}},
            {"trigger": {"url-filter": ".*", "if-domain": ["*cvt-s1.agl010.pro"]}, "action": {"type": "block"}},
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
            forIdentifier: "ScopedBlock_v10",
            encodedContentRuleList: blockRules
        ) { list, _ in
            if let list = list { config.userContentController.add(list) }
        }

        let js = """
        (function() {
            var HIDE_ID = '__scoped_hide__';

            function ensureStyle() {
                if (document.getElementById(HIDE_ID)) return;
                if (!document.head) return;
                var style = document.createElement('style');
                style.id = HIDE_ID;
                style.innerHTML = `
                    header, footer, .header, .footer, .nav, .top-menu, .main-menu,
                    .sidebar, .left-side, .right-side, aside,
                    #header, #footer, #nav, #sidebar,
                    .comments, #comments, .social, .share, .breadcrumbs, .breadcrumb,
                    .yellow-banner, [class*="yellow-banner"],
                    [class*="pinco"], [class*="kysh"],
                    .xsort, .xsort--main, .js-xf-groups, .js-xf-selected,
                    .xfilter__groups, .xsort__selected,
                    iframe[src*="agl010"], iframe[src*="cvt-s1"],
                    iframe[id^="adangle-"], iframe[id^="br5g"], iframe[id^="eas-"],
                    [id^="adangle-"], [id^="br5g"], [id^="eas-"],
                    [class*="ad-branding"], [class*="adangle"],
                    a.moved-tg, .moved, .moved2,
                    .app-download, .app-download.full-b,
                    .branded, .luxury-banner,
                    .rocketme_brand_site_container, .rocketme_brand_image,
                    .rocketme_brand_block_brand, .rocketme_brand_block,
                    .video-block-strip,
                    .usermark__panel,
                    [data-key="4ed59b8f-48b5-417a-9e88-3fb2deccafd1"],
                    [data-adblock-hidden="1"] {
                        display: none !important;
                        visibility: hidden !important;
                        height: 0 !important;
                        min-height: 0 !important;
                        max-height: 0 !important;
                    }
                `;
                document.head.appendChild(style);
            }

            function hideByImage() {
                var imgs = document.querySelectorAll('img');
                for (var i = 0; i < imgs.length; i++) {
                    var img = imgs[i];
                    if (img.getAttribute('data-adblock-hidden')) continue;
                    var src = (img.src || img.getAttribute('data-src') || '').toLowerCase();
                    var isAd = src.indexOf('pinco') !== -1 ||
                               src.indexOf('kysh') !== -1 ||
                               src.indexOf('promocode') !== -1 ||
                               src.indexOf('bahis') !== -1 ||
                               src.indexOf('b5c1d2e8') !== -1 ||
                               src.indexOf('agl010') !== -1;
                    if (!isAd) continue;
                    img.style.setProperty('display', 'none', 'important');
                    img.setAttribute('data-adblock-hidden', '1');
                }
            }

            var pending = false;
            function run() {
                if (pending) return;
                pending = true;
                setTimeout(function() {
                    pending = false;
                    try { ensureStyle(); } catch(e) {}
                    try { hideByImage(); } catch(e) {}
                }, 10);
            }

            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', run);
            } else {
                run();
            }

            try {
                var obs = new MutationObserver(run);
                obs.observe(document.documentElement, { childList: true, subtree: true });
            } catch(e) {}

            [50, 200, 600, 1500, 3500, 8000].forEach(function(d){ setTimeout(run, d); });
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
        webView.isOpaque = true
        webView.backgroundColor = .white
        webView.scrollView.backgroundColor = .white

        context.coordinator.webView = webView
        context.coordinator.onMovieTap = onMovieTap
        context.coordinator.initialURL = url
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url && context.coordinator.lastLoadedURL != url {
            context.coordinator.lastLoadedURL = url
            context.coordinator.initialURL = url
            context.coordinator.retryCount = 0
            uiView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(isLoading: $isLoading) }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        weak var webView: WKWebView?
        let isLoading: Binding<Bool>
        var onMovieTap: ((URL) -> Void)?
        var lastLoadedURL: URL?
        var initialURL: URL?
        var retryCount = 0
        private let maxRetries = 4

        init(isLoading: Binding<Bool>) { self.isLoading = isLoading }

        private func isMovieURL(_ url: URL) -> Bool {
            let s = url.absoluteString
            if s.contains("/filmy/") || s.contains("/v1new/") || s.contains("/serialy/") ||
               s.contains("/top-filmy/") || s.contains("/xfsearch/") ||
               s.contains("/actors/") || s.contains("/directors/") ||
               s.contains("/biografia/") ||
               s.contains("do=search") { return false }
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
            retryCount = 0
            DispatchQueue.main.async { self.isLoading.wrappedValue = false }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.isLoading.wrappedValue = false }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.isLoading.wrappedValue = false }
            guard let u = initialURL, retryCount < maxRetries else { return }
            retryCount += 1
            let delay = Double(retryCount) * 1.5
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                webView.load(URLRequest(url: u))
            }
        }
    }
}
