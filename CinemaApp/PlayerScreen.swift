import SwiftUI
import WebKit

struct PlayerScreen: View {
    let player: Player
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true

    @State private var voices: [String] = []
    @State private var showVoicePicker = false
    @State private var pendingVoice: String? = nil

    @State private var capturedVideoURL: URL?
    @State private var showCaptureAlert = false

    @State private var showNativePlayer = false
    @State private var nativePlayerURL: URL?

    @State private var downloadingURL: URL?
    @State private var downloadedFile: URL?
    @State private var showShareSheet = false

    @State private var showManualURLInput = false
    @State private var manualURLText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let url = URL(string: player.url) {
                    RawPlayerWebView(
                        url: url,
                        isLoading: $isLoading,
                        onVideoURLTap: { videoURL in
                            capturedVideoURL = videoURL
                            showCaptureAlert = true
                        },
                        onVoicesDetected: { list in
                            voices = list
                        },
                        voiceToSelect: $pendingVoice
                    )
                    .edgesIgnoringSafeArea(.bottom)
                }
                if isLoading {
                    ProgressView().scaleEffect(1.6).tint(.white)
                }
                if downloadingURL != nil {
                    ZStack {
                        Color.black.opacity(0.6).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView().tint(.white).scaleEffect(1.4)
                            Text("Скачивание…")
                                .foregroundStyle(.white)
                                .font(.footnote)
                        }
                        .padding(24)
                        .background(Color.black.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .navigationTitle(player.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !voices.isEmpty {
                        Button {
                            showVoicePicker = true
                        } label: {
                            Image(systemName: "waveform")
                        }
                    }
                    Button {
                        showManualURLInput = true
                    } label: {
                        Image(systemName: "link")
                    }
                    Button {
                        downloadedFile = nil
                        manualURLText = ""
                        if let url = URL(string: player.url) {
                            isLoading = true
                            NotificationCenter.default.post(name: .reloadPlayer, object: url)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .confirmationDialog("Выберите озвучку", isPresented: $showVoicePicker, titleVisibility: .visible) {
                ForEach(voices, id: \.self) { v in
                    Button(v) {
                        pendingVoice = v
                    }
                }
                Button("Отмена", role: .cancel) {}
            }
            .alert("Ссылка на видео", isPresented: $showCaptureAlert, presenting: capturedVideoURL) { url in
                Button("Играть в нативном плеере") {
                    nativePlayerURL = url
                    showNativePlayer = true
                }
                Button("Скачать файл") {
                    startDownload(url)
                }
                Button("Отмена", role: .cancel) {}
            } message: { url in
                Text(url.absoluteString)
            }
            .fullScreenCover(isPresented: $showNativePlayer) {
                if let url = nativePlayerURL {
                    ZStack(alignment: .topTrailing) {
                        Color.black.ignoresSafeArea()
                        NativePlayerView(url: url)
                            .ignoresSafeArea()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let file = downloadedFile {
                    ShareSheet(activityItems: [file])
                }
            }
            .alert("Вставить URL видео", isPresented: $showManualURLInput) {
                TextField("https://… .mp4 или .m3u8", text: $manualURLText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Играть") {
                    if let url = URL(string: manualURLText.trimmingCharacters(in: .whitespaces)) {
                        nativePlayerURL = url
                        showNativePlayer = true
                    }
                    manualURLText = ""
                }
                Button("Отмена",(at role: .cancel) { manualURLText = "" }
            } message: {
                Text("Вставьте ссылку из плеера, если он её показывает.")
            }
        }
    }

    private func startDownload(_ url: URL) {
        downloadingURL = url
        URLSession.shared.downloadTask(with: url) { localURL, _, _ in
            DispatchQueue.main.async {
                downloadingURL = nil
            }
            guard let localURL = localURL else { return }
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let name = url.lastPathComponent.isEmpty ? "video.mp4" : url.lastPathComponent
            let dest = docs.appendingPathComponent(name)
            try? FileManager.default.removeItem: dest)
            try? FileManager.default.moveItem(at: localURL, to: dest)
            DispatchQueue.main.async {
                downloadedFile = dest
                showShareSheet = true
            }
        }.resume()
    }
}

extension Notification.Name {
    static let reloadPlayer = Notification.Name("reloadPlayer")
}

struct RawPlayerWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    var onVideoURLTap: ((URL) -> Void)? = nil
    var onVoicesDetected: (([String]) -> Void)? = nil
    @Binding var voiceToSelect: String?

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        if #available(iOS 10.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = []
        }
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let hunterJS = """
        (function() {
            var isCinemar = (location.hostname || '').indexOf('cinemar') !== -1;
            if (!isCinemar || window.__videoHunterInstalled) return;
            window.__videoHunterInstalled = true;

            function reportVideo(url) {
                if (!url) return;
                var low = url.toLowerCase();
                if (low.indexOf('.mp4') === -1 && low.indexOf('.m3u8') === -1 &&
                    low.indexOf('.mkv') === -1 && low.indexOf('.webm') === -1) return;
                try { window.webkit.messageHandlers.videoURL.postMessage(url); } catch(e) {}
            }

            try {
                var _fetch = window.fetch;
                window.fetch = function(input, init) {
                    try { var u = (typeof input === 'string') ? input : (input && input.url); if (u) reportVideo(u); } catch(e) {}
                    return _fetch.apply(this, arguments);
                };
            } catch(e) {}
            try {
                var _open = XMLHttpRequest.prototype.open;
                XMLHttpRequest.prototype.open = function(method, u) {
                    try { if (u) reportVideo(u); } catch(e) {}
                    return _open.apply(this, arguments);
                };
            } catch(e) {}
            try {
                var _click = HTMLAnchorElement.prototype.click;
                HTMLAnchorElement.prototype.click = function() {
                    try { var h = this.href || ''; if (h) reportVideo(h); } catch(e) {}
                    return _click.apply(this, arguments);
                };
            } catch(e) {}

            function sendVoices() {
                try {
                    var btns = document.querySelectorAll('.playlist-dropdown button');
                    var arr = [];
                    for (var i = 0; i < btns.length; i++) {
                        var t = (btns[i].textContent || '').trim();
                        if (t && arr.indexOf(t) === -1) arr.push(t);
                    }
                    if (arr.length > 0) {
                        window.webkit.messageHandlers.voiceList.postMessage(arr);
                    }
                } catch(e) {}
            }
            setTimeout(sendVoices, 2000);
            setTimeout(sendVoices, 5000);
            setTimeout(sendVoices, 9000);

            window.addEventListener('message', function(e) {
                if (!e.data || e.data.type !== 'selectVoice') return;
                var text = e.data.text;
                try {
                    var title = document.querySelector('.playlist-title');
                    if (title) title.click();
                    setTimeout(function() {
                        var all = document.querySelectorAll('.playlist-dropdown button');
                        for (var i = 0; i < all.length; i++) {
                            if ((all[i].textContent || '').trim() === text) {
                                all[i].click();
                                return;
                            }
                        }
                    }, 250);
                } catch(e) {}
            });

            setTimeout(function() {
                if (window.__dlClicked) return;
                window.__dlClicked = true;
                var btn = document.getElementById('player_control_pl-download');
                if (btn) {
                    btn.click();
                    try { btn.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window })); } catch(e) {}
                }
            }, 3000);

            setTimeout(function() {
                if (window.__q720Clicked) return;
                var all = document.querySelectorAll('button, div, span, li, a');
                for (var i = 0; i < all.length; i++) {
                    var el = all[i];
                    if (el.children.length > 2) continue;
                    var t = (el.textContent || '').trim().toLowerCase();
                    if (t === '720p' || t === '720' || t.indexOf('720p') === 0) {
                        window.__q720Clicked = true;
                        try { el.click(); } catch(e) {}
                        try { el.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window })); } catch(e) {}
                        return;
                    }
                }
            }, 5000);
        })();
        """
        let hunterScript = WKUserScript(source: hunterJS, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        config.userContentController.addUserScript(hunterScript)

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
        guard let voice = voiceToSelect, !voice.isEmpty else { return }
        let escaped = voice
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let js = """
        (function retrySelect(count){
            var iframes = document.querySelectorAll('iframe');
            var sent = false;
            for (var i = 0; i < iframes.length; i++) {
                try {
                    if (iframes[i].contentWindow) {
                        iframes[i].contentWindow.postMessage({type:'selectVoice', text:'\(escaped)'}, '*');
                        sent = true;
                    }
                } catch(e) {}
            }
            if (!sent && count < 10) {
                setTimeout(function(){ retrySelect(count+1); }, 300);
            }
        })(0);
        """
        uiView.evaluateJavaScript(js, completionHandler: nil)
        DispatchQueue.main.async {
            voiceToSelect = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

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
            request.setValue("https://mix.kinogo.mu/", forHTTPHeaderField: "Referer")
            request.setValue("https://mix.kinogo.mu/", forHTTPHeaderField: "Origin")
            webView.load(request)
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            if message.name == "videoURL" {
                guard let str = message.body as? String, let url = URL(string: str) else { return }
                DispatchQueue.main.async { self.onVideoURLTap?(url) }
            } else if message.name == "voiceList" {
                guard let arr = message.body as? [String] else { return }
                DispatchQueue.main.async { self.onVoicesDetected?(arr) }
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
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow); return
            }
            if isVideoURL(url) {
                onVideoURLTap?(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                if isVideoURL(url) {
                    onVideoURLTap?(url)
                } else {
                    webView.load(navigationAction.request)
                }
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
