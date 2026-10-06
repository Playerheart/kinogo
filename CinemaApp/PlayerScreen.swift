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
    @State private var showDebug = false

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
            .alert(debugTitle, isPresented: $showDebug) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(debugMessage)
            }
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

    // MARK: - Диагностика (без cookies, с таймаутом)

    private func debugFetch(_ url: URL) {
        debugTitle = "Диагностика"
        debugMessage = "Загрузка…\n\(url.absoluteString)"
        showDebug = true

        let start = Date()

        var req = URLRequest(url: url,
                             cachePolicy: .reloadIgnoringLocalCacheData,
                             timeoutInterval: 12)
        for (k, v) in HLSPrepare.baseHeaders {
            req.setValue(v, forHTTPHeaderField: k)
        }

        URLSession.shared.dataTask(with: req) { data, response, error in
            DispatchQueue.main.async {
                let elapsed = String(format: "%.2f", Date().timeIntervalSince(start))
                if let err = error as NSError? {
                    self.debugMessage = """
                    URL: \(url.absoluteString)

                    ОШИБКА (\(elapsed) с)
                    Домен: \(err.domain)
                    Код: \(err.code)
                    Описание: \(err.localizedDescription)
                    """
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    self.debugMessage = "Нет HTTP-ответа (\(elapsed) с)"
                    return
                }
                let mime = http.mimeType ?? "?"
                let len = data?.count ?? 0
                let head = String(data: (data ?? Data()).prefix(500), encoding: .utf8) ?? "<бинарные данные>"
                let allHeaders = http.allHeaderFields
                    .map { "\($0.key): \($0.value)" }
                    .sorted()
                    .joined(separator: "\n")

                self.debugMessage = """
                HTTP: \(http.statusCode)   (\(elapsed) с)
                MIME: \(mime)
                Длина: \(len) байт

                Первые 500 символов:
                \(head)

                Заголовки:
                \(allHeaders)
                """
            }
        }.resume()

        // Страховка: если URLSession вообще не ответит за 15 с
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            if self.showDebug && self.debugMessage.hasPrefix("Загрузка") {
                self.debugMessage = """
                ТАЙМАУТ 15 сек.
                URLSession не отвечает вообще.

                URL: \(url.absoluteString)

                Значит сервер принимает соединение, но не отдаёт ответ,
                либо iOS не даёт разрешения на этот домен (ATS/DNS).
                """
            }
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
                    self.showDebug = true
                }
            }
        }
    }
}
