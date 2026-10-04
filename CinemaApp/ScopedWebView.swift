import SwiftUI
import WebKit

struct ScopedWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool

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
            forIdentifier: "ScopedBlock_v2",
            encodedContentRuleList: blockRules
        ) { list, _ in
            if let list = list { config.userContentController.add(list) }
        }

        let js = """
        (function() {
            var HIDE_ID = '__scoped_hide__';
            if (!document.getElementById(HIDE_ID)) {
                var style = document.createElement('style');
                style.id = HIDE_ID;
                style.innerHTML = `
                    header, nav, footer,
                    .header, .footer, .nav, .top-menu, .main-menu,
                    .sidebar, .side, .left-side, .right-side, aside,
                    #header, #footer, #nav, #sidebar,
                    .comments, #comments, .related, .related-movies, .sect-related,
                    .social, .share, .breadcrumbs, .breadcrumb,
                    .nav-chain, .nav-links, .top-tabs, .pagination,
                    .footer-menu, .top-nav, .rate-buttons, .movie-rating-buttons,
                    .yellow-banner, [class*="yellow-banner"],
                    [data-adblock-hidden="1"] {
                        display: none !important;
                        visibility: hidden !important;
                        height: 0 !important;
                        min-height: 0 !important;
                    }
                    html, body {
                        background: #000 !important;
                        color: #fff !important;
                        padding: 0 !important;
                        margin: 0 !important;
                        max-width: 100% !important;
                        overflow-x: hidden !important;
                    }
                    body * { max-width: 100% !important; }
                    .content, .main, .page, .wrapper, .container,
                    #content, #main, .content-wrapper, .main-content {
                        padding: 8px !important;
                        margin: 0 !important;
                        max-width: 100% !important;
                        width: 100% !important;
                        background: transparent !important;
                        box-sizing: border-box !important;
                    }
                    .tabs, .tabs__box, .tabs__content, #player, .player-box,
                    .movie__description, .full-story, .description, .short-story,
                    .actors, .persons-list, .persons, .persons-list-box {
                        background: #0d0d0d !important;
                        border-radius: 8px !important;
                        margin-bottom: 12px !important;
                        padding: 8px !important;
                        box-sizing: border-box !important;
                    }
                    .tabs__list, .tabs-list {
                        display: flex !important;
                        flex-wrap: wrap !important;
                        gap: 4px !important;
                    }
                    .tabs__list li, .tabs-list li {
                        padding: 6px 12px !important;
                        border-radius: 6px !important;
                        background: #1a1a1a !important;
                        color: #ccc !important;
                        cursor: pointer !important;
                    }
                    .tabs__list li.active, .tabs-list li.active,
                    .tabs__list li[aria-selected="true"], .tabs-list li[aria-selected="true"] {
                        background: #2563eb !important;
                        color: #fff !important;
                    }
                `;
                document.head.appendChild(style);
            }

            var BAD_TEXTS = [
                'pinco', 'promocode', 'куш', 'bahis yap',
                'алғашқы бәс', 'жениске жет', 'осында жениске',
                'скачай официальное мобильное', 'скачай мобильное приложение',
                'подпишись на kinogo', 'будь в курсе актуальных',
                'рекомендации к просмотру'
            ];

            function isPlayer(el) {
                if (!el.querySelector) return false;
                return el.querySelector('video, iframe[src*="kodik"], iframe[src*="alloha"], iframe[src*="bazon"], iframe[src*="videocdn"], iframe[src*="sibnet"]') !== null;
            }

            function hideByText() {
                var candidates = document.querySelectorAll('div, section, aside, ins, a, span');
                for (var i = candidates.length - 1; i >= 0; i--) {
                    var el = candidates[i];
                    if (el.getAttribute('data-adblock-hidden')) continue;
                    if (el.style.display === 'none') continue;
                    if (isPlayer(el)) continue;
                    if (el.tagName === 'A' && el.href && el.href.indexOf('.html') !== -1) continue;

                    var text = (el.textContent || '').toLowerCase();
                    if (text.length < 3 || text.length > 600) continue;

                    for (var j = 0; j < BAD_TEXTS.length; j++) {
                        if (text.indexOf(BAD_TEXTS[j]) !== -1) {
                            var r = el.getBoundingClientRect();
                            if (r.height > 30 && r.height < 500 && r.width > 150) {
                                el.style.setProperty('display', 'none', 'important');
                                el.style.setProperty('height', '0', 'important');
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
                    var isAd = src.indexOf('pinco') !== -1 ||
                               src.indexOf('kysh') !== -1 ||
                               src.indexOf('promocode') !== -1 ||
                               src.indexOf('bahis') !== -1 ||
                               src.indexOf('b5c1d2e8') !== -1 ||
                               (img.complete && img.naturalWidth === 0);
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
                        p = p.parentElement;
                        depth++;
                    }
                }
            }

            function hideByBackground() {
                var all = document.querySelectorAll('div, section, aside, a');
                for (var i = 0; i < all.length; i++) {
                    var el = all[i];
                    if (el.getAttribute('data-adblock-hidden')) continue;
                    var bg = window.getComputedStyle(el).backgroundImage;
                    if (bg && bg !== 'none') {
                        var lower = bg.toLowerCase();
                        if (lower.indexOf('pinco') !== -1 || lower.indexOf('kysh') !== -1 ||
                            lower.indexOf('promocode') !== -1 || lower.indexOf('b5c1d2e8') !== -1) {
                            el.style.setProperty('display', 'none', 'important');
                            el.setAttribute('data-adblock-hidden', '1');
                        }
                    }
                }
            }

            function activateOnlineTab() {
                try {
                    var tabs = document.querySelectorAll('.tabs__list li, .tabs li, [role="tab"], .tabs__list a, .tabs a');
                    for (var i = 0; i < tabs.length; i++) {
                        var t = (tabs[i].textContent || '').trim().toLowerCase();
                        if (t.indexOf('смотреть онлайн') !== -1) {
                            var isActive = tabs[i].classList.contains('active') ||
                                           tabs[i].getAttribute('aria-selected') === 'true';
                            if (!isActive) tabs[i].click();
                            break;
                        }
                    }
                } catch(e) {}
            }

            var pending = false;
            function run() {
                if (pending) return;
                pending = true;
                setTimeout(function() {
                    pending = false;
                    activateOnlineTab();
                    hideByText();
                    hideByImage();
                    hideByBackground();
                }, 250);
            }

            run();
            try {
                var obs = new MutationObserver(run);
                obs.observe(document.documentElement, { childList: true, subtree: true });
            } catch(e) {}

            [100, 400, 1000, 2000, 3500, 6000, 10000, 15000].forEach(function(d){ setTimeout(run, d); });
        })();
        """
        let script = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        config.userContentController.addUserScript(script)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        context.coordinator.webView = webView
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(isLoading: $isLoading) }

    class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        let isLoading: Binding<Bool>

        init(isLoading: Binding<Bool>) { self.isLoading = isLoading }

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
