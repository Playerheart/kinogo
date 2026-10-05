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
            forIdentifier: "ScopedBlock_v6",
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
                    .xsort, .xsort--main, .js-xf-groups, .js-xf-selected,
                    .xfilter__groups, .xsort__selected,
                    iframe[src*="agl010"], iframe[src*="cvt-s1"],
                    .app-download, .app-download.full-b,
                    .moved, .moved2, .branded, .promo, .luxury-banner,
                    .rocketme_brand_site_container, .rocketme_brand_image,
                    .rocketme_brand_block_brand,
                    [id^="br5g"], [id^="adangle-"], [id^="eas-"],
                    [class*="ad-branding"],
                    [data-key="4ed59b8f-48b5-417a-9e88-3fb2deccafd1"],
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
                'подпишись на kinogo', 'будь в курсе актуальных',
                'без рекламы? вступай', 'без рекламы',
                'всегда доступен', 'бесплатно и без рекламы',
                'будь избранным', 'перейти на kinogo', 'kinogo.luxury',
                'создай свой киного', 'на случай блока',
                'рекомендации к просмотру'
            ];

            var BAD_CLASSES = [
                'branded', 'rocketme_brand', 'app-download', 'moved', 'moved2',
                'yellow-banner', 'promo', 'luxury-banner', 'ad-branding',
                'video-block-strip', 'usermark__panel'
            ];

            function containsPlayer(el) {
                if (!el.querySelector) return false;
                return el.querySelector('video, iframe[src*="cinemar"], iframe[src*="kodik"], iframe[src*="alloha"]') !== null;
            }

            function isPopup(el) {
                if (!el || !el.classList) return false;
                return el.classList.contains('js-person-popup') ||
                       el.classList.contains('person__popup') ||
                       el.classList.contains('person__profile');
            }

            function hasBadClass(el) {
                if (!el || !el.classList) return false;
                var cls = (el.className || '').toString().toLowerCase();
                for (var i = 0; i < BAD_CLASSES.length; i++) {
                    if (cls.indexOf(BAD_CLASSES[i].toLowerCase()) !== -1) return true;
                }
                return false;
            }

            function hideByText() {
                var candidates = document.querySelectorAll('div, section, aside, ins, span, a, strong, p');
                for (var i = candidates.length - 1; i >= 0; i--) {
                    var el = candidates[i];
                    if (el.getAttribute('data-adblock-hidden')) continue;
                    if (el.style && el.style.display === 'none') continue;
                    if (containsPlayer(el)) continue;
                    if (isPopup(el)) continue;

                    var text = (el.textContent || '').toLowerCase();
                    if (text.length < 5 || text.length > 1200) continue;

                    for (var j = 0; j < BAD_TEXTS.length; j++) {
                        if (text.indexOf(BAD_TEXTS[j].toLowerCase()) !== -1) {
                            var r = el.getBoundingClientRect();
                            if (r.height > 20 && r.height < 900 && r.width > 80) {
                                el.style.setProperty('display', 'none', 'important');
                                el.setAttribute('data-adblock-hidden', '1');
                            }
                            break;
                        }
                    }
                }
            }

            function hideByClass() {
                var all = document.querySelectorAll('div, section, aside, a');
                for (var i = 0; i < all.length; i++) {
                    var el = all[i];
                    if (el.getAttribute('data-adblock-hidden')) continue;
                    if (containsPlayer(el)) continue;
                    if (isPopup(el)) continue;
                    if (hasBadClass(el)) {
                        el.style.setProperty('display', 'none', 'important');
                        el.setAttribute('data-adblock-hidden', '1');
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
                               src.indexOf('b5c1d2e8') !== -1 || src.indexOf('agl010') !== -1 ||
                               (img.complete && img.naturalWidth === 0 && src.indexOf('poster') === -1 && src.indexOf('persons') === -1 && src.indexOf('actor') === -1);
                    if (!isAd) continue;
                    img.style.setProperty('display', 'none', 'important');
                    var p = img.parentElement;
                    var depth = 0;
                    while (p && depth < 5) {
                        if (p.getAttribute('data-adblock-hidden')) break;
                        if (p.tagName === 'A' && p.href && p.href.indexOf('.html') !== -1) break;
                        var pr = p.getBoundingClientRect();
                        if (pr.height > 40 && pr.height < 500 && pr.width > 150) {
                            p.style.setProperty('display', 'none', 'important');
                            p.setAttribute('data-adblock-hidden', '1');
                            break;
                        }
                        p = p.parentElement; depth++;
                    }
                }
            }

            function markPersons() {
                var persons = document.querySelectorAll('a.js-person');
                for (var i = 0; i < persons.length; i++) {
                    persons[i].setAttribute('data-person-bound', '1');
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
                    hideByClass();
                    hideByImage();
                    markPersons();
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
