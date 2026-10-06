import SwiftUI
import WebKit

struct PlayerScreen: View {
    let player: Player
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true

    @State private var voices: [String] = []
    @State private var qualities: [String] = []
    @State private var showVoicePicker = false
    @State private var showQualityPicker = false
    @State private var pendingVoice: String? = nil
    @State private var pendingQuality: String? = nil
    @State private var cmdReadQualities = 0

    @State private var voicePromptShown = false
    @State private var qualityPromptShown = false

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
                            if list.isEmpty { return }
                            voices = list
                            // Первый автоматический шаг: показываем выбор озвучки один раз
                            if !voicePromptShown {
                                voicePromptShown = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showVoicePicker = true
                                }
                            }
                        },
                        onQualitiesDetected: { list in
                            if list.isEmpty { return }
                            qualities = list
                            if !qualityPromptShown {
                                qualityPromptShown = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showQualityPicker = true
                                }
                            }
                        },
                        pendingVoice: $pendingVoice,
                        pendingQuality: $pendingQuality,
                        cmdReadQualities: $cmdReadQualities
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
                                .foregroundStyle(.white).font(.footnote)
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
                        qualities = []
                        cmdReadQualities &+= 1
                        showQualityPicker = true
                    } label: {
                        Image(systemName: "tv")
                    }
                    Button {
                        showManualURLInput = true
                    } label: {
                        Image(systemName: "link")
                    }
                    Button {
                        if let url = URL(string: player.url) {
                            isLoading = true
                            voicePromptShown = false
                            qualityPromptShown = false
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
                        // После переключения озвучки запускаем следующий шаг — чтение качеств
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                            qualities = []
                            cmdReadQualities &+= 1
                            showQualityPicker = true
                        }
                    }
                }
                Button("Пропустить", role: .cancel) {
                    // Пользователь не хочет выбирать — открываем качества сразу
                    qualities = []
                    cmdReadQualities &+= 1
                    showQualityPicker = true
                }
            }
            .confirmationDialog("Выберите качество", isPresented: $showQualityPicker, titleVisibility: .visible) {
                if qualities.isEmpty {
                    Text("Сканируем доступные качества…")
                } else {
                    ForEach(qualities, id: \.self) { q in
                        Button(q) {
                            pendingQuality = q
                            // Ничего больше не делаем — URL перехватится автоматически и появится меню
                        }
                    }
                }
                Button("Отмена", role: .cancel) {}
            }
            .alert("Ссылка на видео", isPresented: $showCaptureAlert, presenting: capturedVideoURL) { url in
                Button("Играть в нативном плеере") {
                    nativePlayerURL = url
                    showNativePlayer = true
                }
                Button("Скачать файл") { startDownload(url) }
                Button("Отмена", role: .cancel) {}
            } message: { url in
                Text(url.absoluteString)
            }
            .fullScreenCover(isPresented: $showNativePlayer) {
                if let url = nativePlayerURL {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        NativePlayerView(url: url).ignoresSafeArea()
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
                Button("Отмена", role: .cancel) { manualURLText = "" }
            } message: {
                Text("Вставьте ссылку из плеера, если он её показывает.")
            }
        }
    }

    private func startDownload(_ url: URL) {
        downloadingURL = url
        URLSession.shared.downloadTask(with: url) { localURL, _, _ in
            DispatchQueue.main.async { downloadingURL = nil }
            guard let localURL = localURL else { return }
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let name = url.lastPathComponent.isEmpty ? "video.mp4" : url.lastPathComponent
            let dest = docs.appendingPathComponent(name)
            try? FileManager.default.removeItem(at: dest)
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
    var onQualitiesDetected: (([String]) -> Void)? = nil
    @Binding var pendingVoice: String?
    @Binding var pendingQuality: String?
    @Binding var cmdReadQualities: Int

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        if #available(iOS 10.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = []
        }
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        // JS больше НЕ кликает «Скачать» и «720p» автоматически.
        // Он только читает список озвучек, кликает по «Скачать» когда попросят,
        // собирает список качеств и кликает по выбранному.
        let hunterJS = """
        (function(){
            var isCinemar = (location.hostname||'').indexOf('cinemar') !== -1;
            if (!isCinemar || window.__hunterInstalled) return;
            window.__hunterInstalled = true;

            function reportVideo(u){
                if(!u) return;
                var l=u.toLowerCase();
                if(l.indexOf('.mp4')===-1&&l.indexOf('.m3u8')===-1&&l.indexOf('.mkv')===-1&&l.indexOf('.webm')===-1) return;
                try{window.webkit.messageHandlers.videoURL.postMessage(u);}catch(e){}
            }

            try{var _f=window.fetch;window.fetch=function(i){try{var u=(typeof i==='string')?i:(i&&i.url);if(u)reportVideo(u);}catch(e){}return _f.apply(this,arguments);};}catch(e){}
            try{var _o=XMLHttpRequest.prototype.open;XMLHttpRequest.prototype.open=function(m,u){try{if(u)reportVideo(u);}catch(e){}return _o.apply(this,arguments);};}catch(e){}
            try{var _c=HTMLAnchorElement.prototype.click;HTMLAnchorElement.prototype.click=function(){try{var h=this.href||'';if(h)reportVideo(h);}catch(e){}return _c.apply(this,arguments);};}catch(e){}

            function readVoices(){
                try{
                    var btns=document.querySelectorAll('.playlist-dropdown button');
                    var arr=[];
                    for(var i=0;i<btns.length;i++){
                        var t=(btns[i].textContent||'').trim();
                        if(t&&arr.indexOf(t)===-1) arr.push(t);
                    }
                    if(arr.length) window.webkit.messageHandlers.voiceList.postMessage(arr);
                }catch(e){}
            }

            function clickDownloadButton(){
                var dl=document.getElementById('player_control_pl-download');
                if(dl){
                    try{dl.click();}catch(e){}
                    try{dl.dispatchEvent(new MouseEvent('click',{bubbles:true,cancelable:true,view:window}));}catch(e){}
                }
            }

            function readQualities(){
                clickDownloadButton();
                setTimeout(function(){
                    var map={};
                    var all=document.querySelectorAll('div,button,li,a,span');
                    for(var i=0;i<all.length;i++){
                        var el=all[i];
                        var r=el.getBoundingClientRect();
                        if(r.width<20||r.height<10) continue;
                        var t=(el.textContent||'').trim();
                        if(t.length<3||t.length>30) continue;
                        if(!/^\\d{3,4}p(\\s|$)/i.test(t)) continue;
                        if(!map[t]||el.children.length<map[t].children.length) map[t]=el;
                    }
                    var arr=Object.keys(map);
                    try{window.webkit.messageHandlers.qualityList.postMessage(arr);}catch(e){}
                },1200);
            }

            function selectQuality(text){
                clickDownloadButton();
                setTimeout(function(){
                    var all=document.querySelectorAll('div,button,li,a,span');
                    var best=null;
                    for(var i=0;i<all.length;i++){
                        var el=all[i];
                        var r=el.getBoundingClientRect();
                        if(r.width<20||r.height<10) continue;
                        var t=(el.textContent||'').trim();
                        if(t!==text) continue;
                        if(!best||el.children.length<best.children.length) best=el;
                    }
                    if(best){
                        try{best.click();}catch(e){}
                        try{best.dispatchEvent(new MouseEvent('click',{bubbles:true,cancelable:true,view:window}));}catch(e){}
                    }
                },700);
            }

            window.__hunterReadQualities = readQualities;
            window.__hunterSelectQuality = selectQuality;

            window.addEventListener('message',function(e){
                if(!e.data||!e.data.type) return;
                if(e.data.type==='selectVoice'){
                    var title=document.querySelector('.playlist-title');
                    if(title) title.click();
                    setTimeout(function(){
                        var all=document.querySelectorAll('.playlist-dropdown button');
                        for(var i=0;i<all.length;i++){
                            if((all[i].textContent||'').trim()===e.data.text){all[i].click();return;}
                        }
                    },250);
                } else if(e.data.type==='readQualities'){
                    readQualities();
                } else if(e.data.type==='selectQuality'){
                    selectQuality(e.data.text);
                }
            });

            // Только чтение озвучек, никаких автокликов download/quality
            setTimeout(readVoices,2000);
            setTimeout(readVoices,5000);
            setTimeout(readVoices,9000);
        })();
        """
        let hunterScript = WKUserScript(source: hunterJS, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        config.userContentController.addUserScript(hunterScript)

        config.userContentController.add(context.coordinator, name: "videoURL")
        config.userContentController.add(context.coordinator, name: "voiceList")
        config.userContentController.add(context.coordinator, name: "qualityList")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        context.coordinator.onVideoURLTap = onVideoURLTap
        context.coordinator.onVoicesDetected = onVoicesDetected
        context.coordinator.onQualitiesDetected = onQualitiesDetected
        context.coordinator.webView = webView
        context.coordinator.load(url: url)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Выбор озвучки
        if let voice = pendingVoice, !voice.isEmpty {
            let esc = voice.replacingOccurrences(of: "\\", with: "\\\\")
                           .replacingOccurrences(of: "'", with: "\\'")
            let js = """
            (function retry(n){
                var frames=document.querySelectorAll('iframe');
                for(var i=0;i<frames.length;i++){
                    try{frames[i].contentWindow.postMessage({type:'selectVoice',text:'\(esc)'},'*');}catch(e){}
                }
                if(n<10) setTimeout(function(){retry(n+1);},300);
            })(0);
            """
            uiView.evaluateJavaScript(js, completionHandler: nil)
            DispatchQueue.main.async { pendingVoice = nil }
        }

        // Команда чтения качеств
        if cmdReadQualities > context.coordinator.lastCmdRead {
            context.coordinator.lastCmdRead = cmdReadQualities
            let js = """
            (function retry(n){
                var frames=document.querySelectorAll('iframe');
                for(var i=0;i<frames.length;i++){
                    try{frames[i].contentWindow.eval('window.__hunterReadQualities && window.__hunterReadQualities()');}catch(e){}
                    try{frames[i].contentWindow.postMessage({type:'readQualities'},'*');}catch(e){}
                }
                if(n<5) setTimeout(function(){retry(n+1);},400);
            })(0);
            """
            uiView.evaluateJavaScript(js, completionHandler: nil)
        }

        // Выбор качества
        if let q = pendingQuality, !q.isEmpty {
            let esc = q.replacingOccurrences(of: "\\", with: "\\\\")
                       .replacingOccurrences(of: "'", with: "\\'")
            let js = """
            (function retry(n){
                var frames=document.querySelectorAll('iframe');
                for(var i=0;i<frames.length;i++){
                    try{frames[i].contentWindow.eval("window.__hunterSelectQuality && window.__hunterSelectQuality('\(esc)')");}catch(e){}
                    try{frames[i].contentWindow.postMessage({type:'selectQuality',text:'\(esc)'},'*');}catch(e){}
                }
                if(n<5) setTimeout(function(){retry(n+1);},400);
            })(0);
            """
            uiView.evaluateJavaScript(js, completionHandler: nil)
            DispatchQueue.main.async { pendingQuality = nil }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(isLoading: $isLoading) }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        let isLoading: Binding<Bool>
        var onVideoURLTap: ((URL) -> Void)?
        var onVoicesDetected: (([String]) -> Void)?
        var onQualitiesDetected: (([String]) -> Void)?
        var lastCmdRead: Int = 0
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

        func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "videoURL":
                guard let str = message.body as? String, let url = URL(string: str) else { return }
                DispatchQueue.main.async { self.onVideoURLTap?(url) }
            case "voiceList":
                guard let arr = message.body as? [String] else { return }
                DispatchQueue.main.async { self.onVoicesDetected?(arr) }
            case "qualityList":
                guard let arr = message.body as? [String] else { return }
                DispatchQueue.main.async { self.onQualitiesDetected?(arr) }
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
