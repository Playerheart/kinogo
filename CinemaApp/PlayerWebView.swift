import SwiftUI
import WebKit

struct RawPlayerWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    var onVideoURLTap: ((URL) -> Void)? = nil
    var onVoicesDetected: (([String]) -> Void)? = nil
    @Binding var pendingVoice: String?

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        if #available(iOS 10.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = []
        }
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let hunterScript = WKUserScript(
            source: PlayerJS.hunter,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(hunterScript)

        let muteJS = """
        (function(){
        function muteAll(){
        try{
        var m = document.querySelectorAll('video, audio');
        for (var i = 0; i < m.length; i++){
        var el = m[i];
        try{
        el.muted = true;
        el.volume = 0;
        if (!el.hasAttribute('muted')) el.setAttribute('muted','');
        }catch(e){}
        }
        }catch(e){}
        }
        muteAll();
        setInterval(muteAll, 150);
        try{
        var _play = HTMLMediaElement.prototype.play;
        HTMLMediaElement.prototype.play = function(){
        try{ this.muted = true; this.volume = 0; }catch(e){}
        return _play.apply(this, arguments);
        };
        }catch(e){}
        try{
        var _setAttr = Element.prototype.setAttribute;
        Element.prototype.setAttribute = function(name, value){
        try{
        if (name === 'muted' && value === null) {
        return _setAttr.call(this, 'muted', '');
        }
        }catch(e){}
        return _setAttr.apply(this, arguments);
        };
        }catch(e){}
        try{
        var obs = new MutationObserver(muteAll);
        obs.observe(document.documentElement || document, {childList:true, subtree:true});
        }catch(e){}
        })();
        """
        config.userContentController.addUserScript(
            WKUserScript(source: muteJS, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
        config.userContentController.addUserScript(
            WKUserScript(source: muteJS, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        )

        config.userContentController.add(context.coordinator, name: "videoURL")
        config.userContentController.add(context.coordinator, name: "voiceList")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        context.coordinator.onVideoURLTap = onVideoURLTap
        context.coordinator.onVoicesDetected = onVoicesDetected
        context.coordinator.webView = webView
        context.coordinator.load(url: url)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let voice = pendingVoice, !voice.isEmpty {
            let esc = voice.replacingOccurrences(of: "\\", with: "\\\\")
                           .replacingOccurrences(of: "'", with: "\\'")
            let js = """
            (function(){
            try{window.postMessage({type:'selectVoice',text:'\(esc)'},'*');}catch(e){}
            var frames=document.querySelectorAll('iframe');
            for(var i=0;i<frames.length;i++){
            try{frames[i].contentWindow.postMessage({type:'selectVoice',text:'\(esc)'},'*');}catch(e){}
            }
            })();
            """
            uiView.evaluateJavaScript(js, completionHandler: nil)
            DispatchQueue.main.async { pendingVoice = nil }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(isLoading: $isLoading) }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        let isLoading: Binding<Bool>
        var onVideoURLTap: ((URL) -> Void)?
        var onVoicesDetected: (([String]) -> Void)?
        private var observer: NSObjectProtocol?

        init(isLoading: Binding<Bool>) {
            self.isLoading = isLoading
            super.init()
            observer = NotificationCenter.default.addObserver(
                forName: .reloadPlayer, object: nil, queue: .main
            ) { [weak self] note in
                guard let self = self, let url = note.object as? URL else { return }
                self.load(url: url)
            }
        }

        deinit {
            if let o = observer { NotificationCenter.default.removeObserver(o) }
        }

        func load(url: URL) {
            guard let webView = webView else { return }
            var request = URLRequest(url: url)
            request.setValue(AppConfig.referer, forHTTPHeaderField: "Referer")
            request.setValue(AppConfig.origin,  forHTTPHeaderField: "Origin")
            webView.load(request)
        }

        func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "videoURL":
                guard let str = message.body as? String, let url = URL(string: str) else { return }
                DispatchQueue.main.async { self.onVideoURLTap?(url) }
            case "voiceList":
                guard let arr = message.body as? [String] else { return }
                DispatchQueue.main.async { self.onVoicesDetected?(arr) }
            default: break
            }
        }

        private func isVideoURL(_ url: URL) -> Bool {
            let s = url.absoluteString.lowercased()
            return s.contains(".mp4") || s.contains(".m3u8") ||
                   s.contains(".mkv") || s.contains(".webm") ||
                   s.contains(".mov") || s.contains(".m4v")
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { decisionHandler(.allow); return }
            if isVideoURL(url) { onVideoURLTap?(url); decisionHandler(.cancel); return }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                if isVideoURL(url) { onVideoURLTap?(url) }
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
