import Foundation
import WebKit

@MainActor
final class SiteParser: NSObject {
    static let shared = SiteParser()

    private var webView: WKWebView!
    private var pendingJS: String?
    private var pendingCompletion: ((Result<String, Error>) -> Void)?
    private var loadSucceeded = false
    private var timeoutTask: Task<Void, Never>?

    private override init() {
        super.init()
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        let blockHeavy: [String: Any] = [
            "trigger": ["url-filter": ".*", "resource-type": ["image", "media", "font"]],
            "action": ["type": "block"]
        ]
        if let data = try? JSONSerialization.data(withJSONObject: [blockHeavy]),
           let json = String(data: data, encoding: .utf8) {
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "BlockHeavyResources_v1",
                encodedContentRuleList: json
            ) { list, _ in
                if let list = list { config.userContentController.add(list) }
            }
        }

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    }

    func extract(from url: URL, js: String, waitAfterLoad: TimeInterval = 3.0) async throws -> String {
        if pendingCompletion != nil {
            pendingCompletion?(.failure(ParserError.cancelled))
            pendingCompletion = nil
        }
        return try await withCheckedThrowingContinuation { cont in
            self.pendingJS = js
            self.loadSucceeded = false
            self.pendingCompletion = { result in cont.resume(with: result) }
            self.webView.stopLoading()
            self.webView.load(URLRequest(url: url))

            self.timeoutTask?.cancel()
            self.timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard let self = self, !self.loadSucceeded else { return }
                self.pendingCompletion?(.failure(ParserError.timeout))
                self.pendingCompletion = nil
            }
        }
    }

    private func finishWithJS(_ js: String, wait: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in
            guard let self = self else { return }
            self.webView.evaluateJavaScript(js) { result, error in
                if let error = error {
                    self.pendingCompletion?(.failure(ParserError.jsError(error.localizedDescription)))
                } else if let str = result as? String {
                    self.pendingCompletion?(.success(str))
                } else {
                    self.pendingCompletion?(.failure(ParserError.invalidResult))
                }
                self.pendingCompletion = nil
                self.pendingJS = nil
            }
        }
    }
}

extension SiteParser: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadSucceeded = true
        timeoutTask?.cancel()
        guard let js = pendingJS else { return }
        finishWithJS(js, wait: 4.0)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        pendingCompletion?(.failure(error)); pendingCompletion = nil
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        pendingCompletion?(.failure(error)); pendingCompletion = nil
    }
}
