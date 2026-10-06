import SwiftUI
import WebKit
import AVFoundation

struct PlayerScreen: View {
    let player: Player
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true

    @State private var voices: [String] = []
    @State private var showVoicePicker = false
    @State private var currentVoice: String? = nil
    @State private var pendingVoice: String? = nil

    @State private var capturedVideoURL: URL?
    @State private var showCaptureSheet = false
    @State private var lastCaptureTime: Date = .distantPast

    @State private var showNativePlayer = false
    @State private var nativePlayerURL: URL?

    @State private var downloadingURL: URL?
    @State private var downloadedFile: URL?
    @State private var showShareSheet = false

    @State private var showManualURLInput = false
    @State private var manualURLText = ""

    @State private var debugTitle: String = ""
    @State private var debugMessage: String = ""
    @State private var showDebugOverlay = false
    @State private var debugTick = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let url = URL(string: player.url) {
                    RawPlayerWebView(
                        url: url,
                        isLoading: $isLoading,
                        onVideoURLTap: { videoURL in
                            let normalized = PlayerScreen.normalizeVideoURL(videoURL)
                            if showCaptureSheet {
                                capturedVideoURL = normalized
                                return
                            }
                            let now = Date()
                            if now.timeIntervalSince(lastCaptureTime) < 1.5 { return }
                            lastCaptureTime = now
                            capturedVideoURL = normalized
                            showCaptureSheet = true
                        },
                        onVoicesDetected: { list in
                            if list.isEmpty { return }
                            voices = list
                            if currentVoice == nil { currentVoice = list.first }
                        },
                        pendingVoice: $pendingVoice
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
                        Button { showVoicePicker = true } label: {
                            Image(systemName: "waveform")
                        }
                    }
                    Button {
                        if let url = capturedVideoURL ?? URL(string: player.url) {
                            debugFetch(url)
                        }
                    } label: {
                        Image(systemName: "stethoscope")
                    }
                    Button { showManualURLInput = true } label: {
                        Image(systemName: "link")
                    }
                    Button {
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
                        currentVoice = v
                        pendingVoice = v
                    }
                }
                Button("Отмена", role: .cancel) {}
            }
            .sheet(isPresented: $showCaptureSheet) {
                CaptureSheetView(
                    videoURL: capturedVideoURL,
                    voices: voices,
                    currentVoice: currentVoice,
                    onVoiceChange: { v in
                        currentVoice = v
                        pendingVoice = v
                        capturedVideoURL = nil
                        showCaptureSheet = false
                    },
                    onPlay: { url in
                        showCaptureSheet = false
                        nativePlayerURL = url
                        showNativePlayer = true
                    },
                    onDownload: { url in
                        showCaptureSheet = false
                        startDownload(url)
                    },
                    onCancel: { showCaptureSheet = false }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showNativePlayer) {
                if let url = nativePlayerURL {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        NativePlayerView(url: url).ignoresSafeArea()

                        VStack {
                            HStack {
                                Button {
                                    showNativePlayer = false
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "xmark")
                                        Text("Закрыть")
                                    }
                                    .font(.subheadline).bold()
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .background(Color.black.opacity(0.7))
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                                }
                                Spacer()
                            }
                            .padding()
                            Spacer()
                        }
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
                        nativePlayerURL = PlayerScreen.normalizeVideoURL(url)
                        showNativePlayer = true
                    }
                    manualURLText = ""
                }
                Button("Отмена", role: .cancel) { manualURLText = "" }
            } message: {
                Text("Вставьте ссылку из плеера, если он её показывает.")
            }
        }
        .overlay {
            if showDebugOverlay {
                debugOverlay
            }
        }
    }

    // MARK: - Overlay диагностики

    private var debugOverlay: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Text(debugTitle)
                    .font(.headline)
                    .foregroundStyle(.white)

                ScrollView {
                    Text(debugMessage)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 380)
                .padding(10)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Button {
                    showDebugOverlay = false
                } label: {
                    Text("Закрыть")
                        .font(.subheadline).bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(20)
            .background(Color(white: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(24)
        }
    }

    static func normalizeVideoURL(_ url: URL) -> URL {
        let s = url.absoluteString
        if let r = s.range(of: ":hls:") {
            let trimmed = String(s[..<r.lowerBound])
            if let u = URL(string: trimmed) { return u }
        }
        return url
    }

    // MARK: - Диагностика сети

    private func debugFetch(_ url: URL) {
        debugTitle = "Диагностика сети"
        debugMessage = "▶ Тестирую три URL…\n\n(⏱ 0.0 с)"
        showDebugOverlay = true
        debugTick = 0

        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { t in
            if !self.showDebugOverlay { t.invalidate(); return }
            self.debugTick += 1
            if self.debugTick > 40 { t.invalidate() }
        }

        var results: [String] = []
        let lock = NSLock()
        let group = DispatchGroup()

        let tests: [(String, URL, Bool)] = [
            ("google.com",        URL(string: "https://www.google.com/")!, false),
            ("mix.kinogo.mu",     URL(string: "https://mix.kinogo.mu/")!, false),
            ("host.cinemap.cc",   url, true)
        ]

        for (name, testURL, showBody) in tests {
            group.enter()
            var req = URLRequest(url: testURL,
                                 cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: 8)
            for (k, v) in HLSPrepare.baseHeaders { req.setValue(v, forHTTPHeaderField: k) }
            let start = Date()
            URLSession.shared.dataTask(with: req) { data, response, error in
                let elapsed = String(format: "%.2f", Date().timeIntervalSince(start))
                var line: String
                if let err = error as NSError? {
                    line = "\(name)  ❌  \(elapsed)с\n   \(err.domain)#\(err.code)\n   \(err.localizedDescription)"
                } else if let http = response as? HTTPURLResponse {
                    let mime = http.mimeType ?? "?"
                    let len = data?.count ?? 0
                    var block = "\(name)  ✅  \(elapsed)с\n   HTTP \(http.statusCode)  \(len) б  \(mime)"
                    if showBody, let d = data {
                        let preview = String(data: d.prefix(400), encoding: .utf8)
                            ?? "<бинарные данные>"
                        block += "\n\n   ПЕРВЫЕ 400 СИМВОЛОВ:\n\(preview)"
                    }
                    line = block
                } else {
                    line = "\(name)  ?  \(elapsed)с  нет ответа"
                }
                lock.lock()
                results.append(line)
                let snapshot = results.sorted().joined(separator: "\n\n")
                lock.unlock()
                DispatchQueue.main.async {
                    self.debugMessage = "▶ Завершено: \(results.count) / 3\n\n\(snapshot)"
                }
                group.leave()
            }.resume()
        }

        group.notify(queue: .main) {
            self.debugMessage = "▶ Завершено: 3 / 3\n\n" + results.sorted().joined(separator: "\n\n")
        }
    }

    private func startDownload(_ url: URL) {
        downloadingURL = url
        Downloader.downloadHLS(url: url) { result in
            DispatchQueue.main.async {
                self.downloadingURL = nil
                switch result {
                case .success(let file):
                    self.downloadedFile = file
                    self.showShareSheet = true
                case .failure(let err):
                    self.debugTitle = "Ошибка скачивания"
                    self.debugMessage = err.localizedDescription
                    self.showDebugOverlay = true
                }
            }
        }
    }
}
