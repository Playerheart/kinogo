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

    // MARK: - Диагностика

    private func debugFetch(_ url: URL) {
        debugTitle = "Диагностика"
        debugMessage = "Загрузка…\n\(url.absoluteString)"
        showDebug = true

        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            let relevant = cookies.filter {
                $0.domain.contains("cinemar") || $0.domain.contains("cinemap") || $0.domain.contains("kinogo")
            }
            let cookieStr = relevant.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            let cookieInfo = "Cookies (\(relevant.count)): \(cookieStr.isEmpty ? "—" : cookieStr)\n\n"

            var req = URLRequest(url: url)
            for (k, v) in HLSPrepare.baseHeaders { req.setValue(v, forHTTPHeaderField: k) }
            if !cookieStr.isEmpty { req.setValue(cookieStr, forHTTPHeaderField: "Cookie") }

            URLSession.shared.dataTask(with: req) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        debugMessage = cookieInfo + "Ошибка: \(error.localizedDescription)"
                        return
                    }
                    guard let http = response as? HTTPURLResponse else {
                        debugMessage = cookieInfo + "Нет HTTP-ответа"
                        return
                    }
                    let mime = http.mimeType ?? "?"
                    let len = data?.count ?? 0
                    let head = String(data: (data ?? Data()).prefix(300), encoding: .utf8) ?? "<binary>"
                    debugMessage = """
                    \(cookieInfo)HTTP: \(http.statusCode)
                    MIME: \(mime)
                    Длина: \(len) байт

                    Первые 300 символов:
                    \(head)
                    """
                }
            }.resume()
        }
    }

    // MARK: - Скачивание (ручная сборка HLS через URLSession)

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

// MARK: - Скачивание HLS вручную (без AVAssetExportSession)

enum Downloader {
    enum DL: Error { case http(Int), emptyPlaylist, parseFailed }

    static func downloadHLS(url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            var headers = HLSPrepare.baseHeaders
            let pairs = cookies
                .filter { $0.domain.contains("cinemar") || $0.domain.contains("cinemap") || $0.domain.contains("kinogo") }
                .map { "\($0.name)=\($0.value)" }
            if !pairs.isEmpty { headers["Cookie"] = pairs.joined(separator: "; ") }

            fetchText(url: url, headers: headers) { master in
                switch master {
                case .failure(let e):
                    completion(.failure(e))
                case .success(let text):
                    guard text.contains("#EXTM3U") else {
                        // не HLS — качаем как файл напрямую
                        fetchBinary(url: url, headers: headers, completion: completion)
                        return
                    }
                    // выбираем первый вариант из master
                    let variantURL = parseFirstVariant(text, base: url) ?? url
                    fetchText(url: variantURL, headers: headers) { variantRes in
                        switch variantRes {
                        case .failure(let e): completion(.failure(e))
                        case .success(let vtext):
                            let segments = parseSegments(vtext, base: variantURL)
                            guard !segments.isEmpty else {
                                completion(.failure(DL.emptyPlaylist))
                                return
                            }
                            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                            let dest = docs.appendingPathComponent("video.ts")
                            try? FileManager.default.removeItem(at: dest)
                            FileManager.default.createFile(atPath: dest.path, contents: nil)
                            guard let handle = try? FileHandle(forWritingTo: dest) else {
                                completion(.failure(DL.parseFailed))
                                return
                            }
                            let group = DispatchGroup()
                            var hadError: Error?
                            for seg in segments {
                                group.enter()
                                fetchBinary(url: seg, headers: headers) { res in
                                    if case .success(let fileURL) = res,
                                       let data = try? Data(contentsOf: fileURL) {
                                        handle.write(data)
                                    } else if case .failure(let e) = res, hadError == nil {
                                        hadError = e
                                    }
                                    group.leave()
                                }
                            }
                            group.notify(queue: .global()) {
                                try? handle.close()
                                if let e = hadError { completion(.failure(e)); return }
                                completion(.success(dest))
                            }
                        }
                    }
                }
            }
        }
    }

    private static func fetchText(url: URL, headers: [String: String], completion: @escaping (Result<String, Error>) -> Void) {
        var req = URLRequest(url: url)
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        URLSession.shared.dataTask(with: req) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(DL.parseFailed)); return
            }
            guard (200...299).contains(http.statusCode) else {
                completion(.failure(DL.http(http.statusCode))); return
            }
            let text = String(data: data ?? Data(), encoding: .utf8) ?? ""
            completion(.success(text))
        }.resume()
    }

    private static func fetchBinary(url: URL, headers: [String: String], completion: @escaping (Result<URL, Error>) -> Void) {
        var req = URLRequest(url: url)
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        URLSession.shared.downloadTask(with: req) { local, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(DL.parseFailed)); return
            }
            guard (200...299).contains(http.statusCode) else {
                completion(.failure(DL.http(http.statusCode))); return
            }
            guard let local = local else { completion(.failure(DL.parseFailed)); return }
            completion(.success(local))
        }.resume()
    }

    private static func parseFirstVariant(_ master: String, base: URL) -> URL? {
        let lines = master.components(separatedBy: "\n")
        for l in lines {
            let t = l.trimmingCharacters(in: .whitespaces)
            if t.isEmpty || t.hasPrefix("#") { continue }
            if let u = URL(string: t, relativeTo: base)?.absoluteURL { return u }
        }
        return nil
    }

    private static func parseSegments(_ playlist: String, base: URL) -> [URL] {
        var out: [URL] = []
        for l in playlist.components(separatedBy: "\n") {
            let t = l.trimmingCharacters(in: .whitespaces)
            if t.isEmpty || t.hasPrefix("#") { continue }
            if let u = URL(string: t, relativeTo: base)?.absoluteURL { out.append(u) }
        }
        return out
    }
}
