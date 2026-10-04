import SwiftUI
import WebKit

struct PlayerView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        if #available(iOS 10.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = []
        }
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        webView.scrollView.isScrollEnabled = true
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url {
            uiView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Открываем сторонние ссылки в Safari, не уходя с плеера
            if let u = navigationAction.request.url,
               navigationAction.navigationType == .linkActivated,
               !u.absoluteString.contains("kodik") &&
               !u.absoluteString.contains("alloha") &&
               !u.absoluteString.contains("bazon") &&
               !u.absoluteString.contains("videocdn") &&
               !u.absoluteString.contains("sibnet") {
                UIApplication.shared.open(u)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewControllerWrapper {
        SFSafariViewControllerWrapper(url: url)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewControllerWrapper, context: Context) {}
}

import SafariServices
final class SFSafariViewControllerWrapper: UIViewController {
    private let url: URL
    init(url: URL) { self.url = url; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let vc = SFSafariViewController(url: url)
        present(vc, animated: true)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
