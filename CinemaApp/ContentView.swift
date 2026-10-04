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
        
        let js = """
        (function() {
            window.open = function() { return null; };
            window.alert = function() { return; };
            window.confirm = function() { return false; };
            window.prompt = function() { return null; };

            var HIDE_STYLE_ID = '__adblock_style__';
            var AD_URL_KEYWORDS = ['pinco', 'kysh', 'promocode', 'bahis', 'kazanmak',
                                   'b5c1d2e8c9982e3b965a27ac72ru7284cc', 'pincogames',
                                   'kasino', 'casino', 'betting', 'bet',
                                   'advert', 'sponsor', 'banner'];

            var CLOSE_SELECTORS = [
                '[class*="close" i]', '[class*="Close" i]', '[class*="CLOSE"]',
                '[id*="close" i]', '[id*="Close" i]',
                '[class*="dismiss" i]', '[id*="dismiss" i]',
                '[class*="btn-close" i]', '[class*="btn_close" i]', '[class*="btnClose" i]',
                '[class*="ad-close" i]', '[class*="ad_close" i]', '[class*="adClose" i]',
                '[class*="modal-close" i]', '[class*="popup-close" i]',
                '[class*="banner-close" i]', '[class*="banner_close" i]',
                '[class*="close-btn" i]', '[class*="close_btn" i]', '[class*="closeBtn" i]',
                '[aria-label*="close" i]', '[aria-label*="закрыть" i]',
                '[aria-label*="Закрыть" i]', '[aria-label*="dismiss" i]',
                '[title*="close" i]', '[title*="закрыть" i]', '[title*="Close" i]',
                '[data-action*="close" i]', '[data-dismiss]', '[data-close]',
                '[data-role*="close" i]',
                'button.close', 'div.close', 'span.close', 'a.close',
                'button.btn-close', 'button[class*="close"]',
                '.close-button', '.closeButton', '.close_btn',
                '.popup__close', '.modal__close', '.banner__close',
                '.close-icon', '.closeIcon', '.close_icon',
                'svg[class*="close" i]', 'svg[class*="x" i]',
                'button[aria-label*="x" i]', 'button[aria-label*="х" i]'
            ];

            // Типовые имена классов для нижних прилипающих баннеров
            var STICKY_BOTTOM_SELECTORS = [
                '[class*="sticky-ad" i]', '[class*="sticky_ad" i]', '[class*="stickyAd" i]',
                '[id*="sticky-ad" i]', '[id*="stickyAd" i]',
                '[class*="sticky-banner" i]', '[class*="stickyBanner" i]',
                '[class*="sticky-bottom" i]', '[class*="stickyBottom" i]',
                '[class*="floor-banner" i]', '[class*="floor_banner" i]', '[class*="floorBanner" i]',
                '[class*="floor-ad" i]', '[class*="floorAd" i]', '[class*="floor_ad" i]',
                '[class*="mobile-bottom-ad" i]', '[class*="mobile_bottom_ad" i]',
                '[class*="mobileBottomAd" i]',
                '[class*="bottom-ad" i]', '[class*="bottom_ad" i]', '[class*="bottomAd" i]',
                '[id*="bottom-ad" i]', '[id*="bottomAd" i]',
                '[class*="fixed-bottom" i]', '[class*="fixed_bottom" i]', '[class*="fixedBottom" i]',
                '[class*="anchor-ad" i]', '[class*="anchorAd" i]',
                '[class*="floating-ad" i]', '[class*="floatingAd" i]',
                '[class*="interstitial" i]', '[class*="interstitial-ad" i]',
                '[class*="adhesion" i]', '[class*="adhesive" i]',
                '[class*="smart-banner" i]', '[class*="smartBanner" i]',
                '.gpt-ad', '.gpt-slot', '.pb-ad', '.gads',
                '[id^="google_ads_"]', '[id*="div-gpt-ad"]', '[id*="aswift"]'
            ];

            function urlIsAd(url) {
                if (!url) return false;
                url = String(url).toLowerCase();
                for (var i = 0; i < AD_URL_KEYWORDS.length; i++) {
                    if (url.indexOf(AD_URL_KEYWORDS[i]) !== -1) return true;
                }
                return false;
            }

            function isVisible(el) {
                if (!el || !el.getBoundingClientRect) return false;
                var r = el.getBoundingClientRect();
                if (r.width < 4 || r.height < 4) return false;
                var st = window.getComputedStyle(el);
                if (st.display === 'none' || st.visibility === 'hidden') return false;
                if (parseFloat(st.opacity) === 0) return false;
                return true;
            }

            function hardClick(el) {
                if (!el) return;
                try {
                    var opts = { bubbles: true, cancelable: true, view: window };
                    el.dispatchEvent(new PointerEvent('pointerdown', opts));
                    el.dispatchEvent(new PointerEvent('pointerup', opts));
                } catch(e) {}
                try {
                    var tOpts = { bubbles: true, cancelable: true, view: window };
                    el.dispatchEvent(new TouchEvent('touchstart', tOpts));
                    el.dispatchEvent(new TouchEvent('touchend', tOpts));
                } catch(e) {}
                try {
                    ['mousedown','mouseup','click'].forEach(function(t) {
                        el.dispatchEvent(new MouseEvent(t, { bubbles: true, cancelable: true, view: window }));
                    });
                } catch(e) {}
                try { if (typeof el.click === 'function') el.click(); } catch(e) {}
                try { if (el.onclick) el.onclick.call(el, new MouseEvent('click')); } catch(e) {}
            }

            function forceHide(el) {
                if (!el || !el.style) return;
                el.style.setProperty('display', 'none', 'important');
                el.style.setProperty('visibility', 'hidden', 'important');
                el.style.setProperty('opacity', '0', 'important');
                el.style.setProperty('pointer-events', 'none', 'important');
                el.style.setProperty('height', '0', 'important');
                el.style.setProperty('max-height', '0', 'important');
                el.setAttribute('data-adblock-hidden', '1');
            }

            function hideAncestorOverlay(el, maxDepth) {
                var p = el;
                var depth = 0;
                maxDepth = maxDepth || 10;
                while (p && depth < maxDepth) {
                    var st = window.getComputedStyle(p);
                    var z = parseInt(st.zIndex) || 0;
                    var pos = st.position;
                    if (pos === 'fixed' || (pos === 'absolute' && z > 50)) {
                        forceHide(p);
                        return p;
                    }
                    p = p.parentElement;
                    depth++;
                }
                return null;
            }

            function injectStyle() {
                if (document.getElementById(HIDE_STYLE_ID)) return;
                var style = document.createElement('style');
                style.id = HIDE_STYLE_ID;
                style.innerHTML = `
                    [class*="ads"], [id*="ads"], [class*="banner"], [id*="banner"],
                    [class*="popup"], [class*="popunder"], [class*="overlay"],
                    .adsbygoogle, iframe[src*="ads"], iframe[src*="banner"],
                    iframe[src*="promo"], a[href*="googlesyndication"],
                    a[href*="adservice"], .ad-container, .ad-wrapper,
                    iframe[src*="pincogames"], iframe[src*="pinco"],
                    img[src*="pinco"], [href*="pinco"], [class*="pinco"],
                    [id*="pinco"], iframe[src*="bet"], iframe[src*="casino"],
                    img[src*="b5c1d2e8c9982e3b965a27ac72ru7284cc"],
                    iframe[src*="b5c1d2e8c9982e3b965a27ac72ru7284cc"],
                    [src*="pinco_banner"], [href*="pinco_banner"],
                    [src*="kysh"], [class*="kysh"], [id*="kysh"],
                    [src*="promocode"], [class*="promocode"],
                    a[href*="bahis"], a[href*="kazanmak"], a[href*="kazan"],
                    [class*="sticky-ad" i], [class*="sticky_ad" i], [class*="stickyAd" i],
                    [id*="sticky-ad" i], [id*="stickyAd" i],
                    [class*="sticky-banner" i], [class*="stickyBanner" i],
                    [class*="sticky-bottom" i], [class*="stickyBottom" i],
                    [class*="floor-banner" i], [class*="floor_banner" i], [class*="floorBanner" i],
                    [class*="floor-ad" i], [class*="floorAd" i], [class*="floor_ad" i],
                    [class*="mobile-bottom-ad" i], [class*="mobile_bottom_ad" i],
                    [class*="mobileBottomAd" i],
                    [class*="bottom-ad" i], [class*="bottom_ad" i], [class*="bottomAd" i],
                    [class*="fixed-bottom" i], [class*="fixedBottom" i],
                    [class*="anchor-ad" i], [class*="anchorAd" i],
                    [class*="floating-ad" i], [class*="floatingAd" i],
                    [class*="interstitial" i], [class*="adhesion" i],
                    [class*="smart-banner" i], [class*="smartBanner" i],
                    [id^="google_ads_"], [id*="div-gpt-ad"],
                    [data-adblock-hidden="1"] {
                        display: none !important;
                        visibility: hidden !important;
                        opacity: 0 !important;
                        pointer-events: none !important;
                        height: 0 !important;
                        max-height: 0 !important;
                        width: 0 !important;
                        max-width: 0 !important;
                        position: absolute !important;
                        top: -99999px !important;
                        left: -99999px !important;
                        z-index: -1 !important;
                    }
                `;
                document.head.appendChild(style);
            }

            function removeScripts() {
                var scripts = document.getElementsByTagName('script');
                for (var i = scripts.length - 1; i >= 0; i--) {
                    var src = scripts[i].src;
                    if (src && urlIsAd(src)) {
                        scripts[i].parentNode.removeChild(scripts[i]);
                    }
                }
            }

            function hideAdMedia() {
                var media = document.querySelectorAll('img, iframe, video, embed, object');
                for (var i = 0; i < media.length; i++) {
                    var el = media[i];
                    var src = (el.getAttribute('src') || el.getAttribute('data-src') || '').toLowerCase();
                    var isBroken = el.tagName === 'IMG' && el.complete && el.naturalWidth === 0;
                    if (urlIsAd(src) || isBroken) {
                        forceHide(el);
                        hideAncestorOverlay(el, 8);
                    }
                }
            }

            // Скрываем явные sticky/floor/bottom баннеры по селекторам
            function hideStickyBottomAds() {
                for (var s = 0; s < STICKY_BOTTOM_SELECTORS.length; s++) {
                    var list;
                    try {
                        list = document.querySelectorAll(STICKY_BOTTOM_SELECTORS[s]);
                    } catch(e) { continue; }
                    for (var i = 0; i < list.length; i++) {
                        var el = list[i];
                        // Не трогаем плеер
                        if (el.querySelector && el.querySelector('video, iframe[src*="kodik"], iframe[src*="alloha"], iframe[src*="bazon"], iframe[src*="videocdn"]')) continue;
                        forceHide(el);
                    }
                }
            }

            // Автопоиск ЛЮБОГО элемента, зафиксированного снизу экрана
            function hideFixedBottomElements() {
                var all = document.querySelectorAll('div, section, aside, footer, ins');
                for (var i = 0; i < all.length; i++) {
                    var el = all[i];
                    if (el.getAttribute('data-adblock-hidden')) continue;
                    var st = window.getComputedStyle(el);
                    if (st.position !== 'fixed' && st.position !== 'sticky') continue;

                    var r = el.getBoundingClientRect();
                    if (r.width < 100 || r.height < 30) continue;
                    if (r.height > 400) continue;              // не баннер
                    if (r.width > window.innerWidth + 5) continue;

                    // Снизу экрана?
                    var isBottom = (window.innerHeight - r.bottom) < 30;
                    var isFullWidth = (r.width / window.innerWidth) > 0.7;
                    if (!isBottom || !isFullWidth) continue;

                    // Содержит ли рекламу?
                    var html = el.innerHTML || '';
                    var hasAdImg = false;
                    var imgs = el.querySelectorAll('img');
                    for (var k = 0; k < imgs.length; k++) {
                        var isrc = (imgs[k].getAttribute('src') || '').toLowerCase();
                        if (urlIsAd(isrc) || (imgs[k].complete && imgs[k].naturalWidth === 0)) {
                            hasAdImg = true;
                            break;
                        }
                    }
                    var hasAdIframe = false;
                    var iframes = el.querySelectorAll('iframe');
                    for (var j = 0; j < iframes.length; j++) {
                        var fsrc = (iframes[j].getAttribute('src') || '').toLowerCase();
                        if (urlIsAd(fsrc)) {
                            hasAdIframe = true;
                            break;
                        }
                    }
                    var htmlLower = html.toLowerCase();
                    var hasAdWordInHTML = htmlLower.indexOf('pinco') !== -1 ||
                                          htmlLower.indexOf('kysh') !== -1 ||
                                          htmlLower.indexOf('промокод') !== -1 ||
                                          htmlLower.indexOf('promocode') !== -1 ||
                                          htmlLower.indexOf('bahis') !== -1 ||
                                          htmlLower.indexOf('kazanmak') !== -1 ||
                                          htmlLower.indexOf('алғашқы') !== -1 ||
                                          htmlLower.indexOf('жеңіске') !== -1 ||
                                          htmlLower.indexOf('жениске') !== -1;

                    if (hasAdImg || hasAdIframe || hasAdWordInHTML) {
                        forceHide(el);
                    }
                }
            }

            // Детект инлайн-стилей вида "position: fixed; bottom: 0"
            function hideInlineFixedBottom() {
                var all = document.querySelectorAll('[style]');
                for (var i = 0; i < all.length; i++) {
                    var el = all[i];
                    if (el.getAttribute('data-adblock-hidden')) continue;
                    var st = el.getAttribute('style') || '';
                    if (st.toLowerCase().indexOf('fixed') === -1) continue;
                    if (st.toLowerCase().indexOf('bottom') === -1) continue;

                    var r = el.getBoundingClientRect();
                    if (r.width < 100 || r.height < 30) continue;
                    if (r.height > 400) continue;

                    // Проверяем содержимое
                    if (el.querySelector && el.querySelector('video, iframe[src*="kodik"], iframe[src*="alloha"]')) continue;

                    var html = (el.innerHTML || '').toLowerCase();
                    var imgs = el.querySelectorAll('img');
                    var hasAdImg = false;
                    for (var k = 0; k < imgs.length; k++) {
                        var src = (imgs[k].getAttribute('src') || '').toLowerCase();
                        if (urlIsAd(src) || (imgs[k].complete && imgs[k].naturalWidth === 0)) {
                            hasAdImg = true;
                            break;
                        }
                    }
                    var hasAdWord = html.indexOf('pinco') !== -1 || html.indexOf('kysh') !== -1 ||
                                    html.indexOf('promocode') !== -1 || html.indexOf('bahis') !== -1 ||
                                    html.indexOf('алғашқы') !== -1 || html.indexOf('жеңіске') !== -1 ||
                                    html.indexOf('kasino') !== -1 || html.indexOf('casino') !== -1;
                    if (hasAdImg || hasAdWord) {
                        forceHide(el);
                    }
                }
            }

            function clickAllCloseButtons() {
                for (var s = 0; s < CLOSE_SELECTORS.length; s++) {
                    var list;
                    try {
                        list = document.querySelectorAll(CLOSE_SELECTORS[s]);
                    } catch(e) { continue; }
                    for (var i = 0; i < list.length; i++) {
                        var el = list[i];
                        if (!isVisible(el)) continue;
                        var r = el.getBoundingClientRect();
                        if (r.width > 200 || r.height > 200) continue;
                        hardClick(el);
                        if (el.parentElement) hardClick(el.parentElement);
                        if (el.parentElement && el.parentElement.parentElement) {
                            hardClick(el.parentElement.parentElement);
                        }
                        forceHide(el);
                        hideAncestorOverlay(el, 10);
                    }
                }
            }

            function clickByTextClose() {
                if (!document.body) return;
                var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null);
                var targets = ['×','✕','✖','⨯','✗','X','x','Х','х','ⓧ','❌','❎','⨉'];
                var node;
                while ((node = walker.nextNode())) {
                    var t = (node.nodeValue || '').trim();
                    if (t.length === 0 || t.length > 3) continue;
                    if (targets.indexOf(t) === -1) continue;
                    var el = node.parentElement;
                    if (!el) continue;
                    var clickable = el;
                    var depth = 0;
                    while (clickable && depth < 5) {
                        var st = window.getComputedStyle(clickable);
                        if (st.cursor === 'pointer' || clickable.tagName === 'BUTTON' ||
                            clickable.tagName === 'A' || clickable.onclick ||
                            clickable.getAttribute('role') === 'button') break;
                        clickable = clickable.parentElement;
                        depth++;
                    }
                    var target = clickable || el;
                    if (isVisible(target)) {
                        hardClick(target);
                        forceHide(target);
                        hideAncestorOverlay(target, 10);
                    }
                }
            }

            function clickSvgClose() {
                var svgs = document.querySelectorAll('svg');
                for (var i = 0; i < svgs.length; i++) {
                    var svg = svgs[i];
                    if (!isVisible(svg)) continue;
                    var r = svg.getBoundingClientRect();
                    if (r.width > 90 || r.height > 90) continue;
                    if (Math.abs(r.width - r.height) > 15) continue;
                    hardClick(svg);
                    if (svg.parentElement) hardClick(svg.parentElement);
                    forceHide(svg);
                    if (svg.parentElement) forceHide(svg.parentElement);
                    hideAncestorOverlay(svg, 10);
                }
            }

            function clickAdCornerButtons() {
                var candidates = document.querySelectorAll('div, section, aside');
                for (var i = 0; i < candidates.length; i++) {
                    var c = candidates[i];
                    if (c.getAttribute('data-adblock-hidden')) continue;
                    var st = window.getComputedStyle(c);
                    if (st.position !== 'fixed' && st.position !== 'absolute') continue;
                    var z = parseInt(st.zIndex) || 0;
                    if (z < 100) continue;
                    var cr = c.getBoundingClientRect();
                    if (cr.width < 80 || cr.height < 50) continue;
                    if (cr.top > window.innerHeight || cr.bottom < 0) continue;

                    var corners = [
                        {x: cr.right, y: cr.top, area: 130},
                        {x: cr.right, y: cr.bottom, area: 130}
                    ];
                    var inner = c.querySelectorAll('button, a, span, div, svg, i');
                    for (var j = 0; j < inner.length; j++) {
                        var el = inner[j];
                        if (!isVisible(el)) continue;
                        if (el.children.length > 2) continue;
                        var r = el.getBoundingClientRect();
                        if (r.width < 15 || r.width > 80) continue;
                        if (r.height < 15 || r.height > 80) continue;
                        if (Math.abs(r.width - r.height) > 20) continue;
                        var cx = r.left + r.width / 2;
                        var cy = r.top + r.height / 2;
                        for (var k = 0; k < corners.length; k++) {
                            var cor = corners[k];
                            if (Math.hypot(cx - cor.x, cy - cor.y) < cor.area) {
                                hardClick(el);
                                forceHide(el);
                                break;
                            }
                        }
                    }
                }
            }

            function hideEmptyOverlays() {
                var candidates = document.querySelectorAll('div, section, aside, span');
                for (var i = 0; i < candidates.length; i++) {
                    var el = candidates[i];
                    if (el.getAttribute('data-adblock-hidden')) continue;
                    var st = window.getComputedStyle(el);
                    if (st.position !== 'fixed' && st.position !== 'absolute') continue;
                    var z = parseInt(st.zIndex) || 0;
                    if (z < 500) continue;
                    var r = el.getBoundingClientRect();
                    if (r.width < 40 || r.height < 40) continue;
                    var hasPlayer = el.querySelectorAll('video, iframe[src*="kodik"], iframe[src*="alloha"], iframe[src*="bazon"], iframe[src*="videocdn"]').length > 0;
                    if (hasPlayer) continue;
                    var textLen = (el.textContent || '').trim().length;
                    if (textLen < 30) {
                        forceHide(el);
                    }
                }
            }

            var isRunning = false;
            function runAll() {
                if (isRunning) return;
                isRunning = true;
                try {
                    injectStyle();
                    removeScripts();
                    hideAdMedia();
                    hideStickyBottomAds();
                    hideFixedBottomElements();
                    hideInlineFixedBottom();
                    clickAllCloseButtons();
                    clickByTextClose();
                    clickSvgClose();
                    clickAdCornerButtons();
                    hideEmptyOverlays();
                } finally {
                    isRunning = false;
                }
            }

            runAll();

            var pending = false;
            function scheduleRun() {
                if (pending) return;
                pending = true;
                setTimeout(function() { pending = false; runAll(); }, 250);
            }

            try {
                var observer = new MutationObserver(scheduleRun);
                observer.observe(document.documentElement, {
                    childList: true,
                    subtree: true,
                    attributes: true,
                    attributeFilter: ['class', 'style', 'id']
                });
            } catch(e) {}

            // Скролл и ресайз: нижние sticky-баннеры часто появляются/пересоздаются при скролле
            var scrollTimer = null;
            function onScrollOrResize() {
                if (scrollTimer) clearTimeout(scrollTimer);
                scrollTimer = setTimeout(runAll, 150);
            }
            try {
                window.addEventListener('scroll', onScrollOrResize, { passive: true });
                window.addEventListener('resize', onScrollOrResize, { passive: true });
            } catch(e) {}

            var delays = [80, 150, 300, 500, 800, 1200, 1800, 2500, 3500, 5000,
                          7000, 10000, 15000, 22000, 30000, 45000, 60000];
            delays.forEach(function(d) { setTimeout(runAll, d); });
        })();
        """
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
        
        let identifier = "AdBlockRules_v6"
        
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: identifier,
            encodedContentRuleList: jsonString
        ) { (contentRuleList, error) in
            if let error = error {
                print("Ошибка компиляции правил блокировки: \(error.localizedDescription)")
            }
            if let contentRuleList = contentRuleList {
                controller.add(contentRuleList)
                print("Правила v6 загружены (\(rulesArray.count) шт.)")
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
