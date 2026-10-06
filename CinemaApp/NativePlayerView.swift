import SwiftUI
import WebKit

struct NativePlayerView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        if #available(iOS 10.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = []
        }
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false

        // HTML-обёртка вокруг m3u8 — WebKit сам откроет встроенный HLS-плеер.
        let src = url.absoluteString
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
        <style>
        html, body { margin:0; padding:0; background:#000; width:100%; height:100%; overflow:hidden; }
        video { width:100%; height:100%; background:#000; }
        </style>
        </head>
        <body>
        <video id="v" src="\(src)" controls autoplay playsinline webkit-playsinline preload="auto"></video>
        <script>
        var v = document.getElementById('v');
        v.addEventListener('error', function(){
            try { window.webkit.messageHandlers.playerError.postMessage(String(v.error && v.error.code)); } catch(e){}
        });
        // Пытаемся запустить сразу (на случай, если политика autoplay зарежет)
        setTimeout(function(){ v.play().catch(function(e){}); }, 300);
        </script>
        </body>
        </html>
        """

        config.userContentController.add(context.coordinator, name: "playerError")
        webView.loadHTMLString(html, baseURL: nil)

        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKScriptMessageHandler {
        weak var webView: WKWebView?
        func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
            // пока просто молча логируем
            print("playerError code=\(message.body)")
        }
    }
}
