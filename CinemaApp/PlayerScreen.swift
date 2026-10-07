import SwiftUI
import WebKit
import UIKit

struct PlayerScreen: View {
    let player: Player
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true

    @State private var voices: [String] = []
    @State private var showVoicePicker = false
    @State private var currentVoice: String? = nil
    @State private var pendingVoice: String? = nil

    @State private var seasons: [String] = []
    @State private var episodes: [String] = []
    @State private var currentSeason: String? = nil
    @State private var currentEpisode: String? = nil
    @State private var pendingSeason: String? = nil
    @State private var pendingEpisode: String? = nil

    @State private var capturedVideoURL: URL?
    @State private var showCaptureSheet = false
    @State private var lastCaptureTime: Date = .distantPast

    @State private var showManualURLInput = false
    @State private var manualURLText = ""

    @State private var showCinemarDiag = false
    @State private var cinemarDiagText = ""

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
                        onSeasonsDetected: { list in
                            if list.isEmpty { return }
                            seasons = list
                            if currentSeason == nil { currentSeason = list.first }
                        },
                        onEpisodesDetected: { list in
                            if list.isEmpty { return }
                            episodes = list
                            if currentEpisode == nil { currentEpisode = list.first }
                        },
                        onCinemarDiag: { text in
                            cinemarDiagText = text
                            showCinemarDiag = true
                        },
                        pendingVoice: $pendingVoice,
                        pendingSeason: $pendingSeason,
                        pendingEpisode: $pendingEpisode
                    )
                    .opacity(0)
                    .allowsHitTesting(false)
                    .edgesIgnoringSafeArea(.all)
                }

                VStack(spacing: 14) {
                    ProgressView()
                        .scaleEffect(1.6)
                        .tint(.white)
                    Text("Подготовка видео…")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
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
                        runCinemarDiagnostics()
                    } label: {
                        Image(systemName: "stethoscope")
                    }
                    Button { showManualURLInput = true } label: {
                        Image(systemName: "link")
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
                    seasons: seasons,
                    episodes: episodes,
                    currentSeason: currentSeason,
                    currentEpisode: currentEpisode,
                    onVoiceChange: { v in
                        currentVoice = v
                        pendingVoice = v
                        capturedVideoURL = nil
                    },
                    onSeasonChange: { s in
                        currentSeason = s
                        currentEpisode = nil
                        episodes = []
                        pendingSeason = s
                        capturedVideoURL = nil
                    },
                    onEpisodeChange: { e in
                        currentEpisode = e
                        pendingEpisode = e
                        capturedVideoURL = nil
                    },
                    onOpenInSafari: { url in
                        UIPasteboard.general.string = url.absoluteString
                        showCaptureSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            dismiss()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                    },
                    onShare: { url in
                        presentShareSheet(for: url)
                    },
                    onCopy: { url in
                        UIPasteboard.general.string = url.absoluteString
                        showCaptureSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            dismiss()
                        }
                    },
                    onCancel: {
                        showCaptureSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            dismiss()
                        }
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .alert("Вставить URL видео", isPresented: $showManualURLInput) {
                TextField("https://… .mp4 или .m3u8", text: $manualURLText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Скопировать") {
                    let trimmed = manualURLText.trimmingCharacters(in: .whitespaces)
                    if let url = URL(string: trimmed) {
                        UIPasteboard.general.string = PlayerScreen.normalizeVideoURL(url).absoluteString
                    }
                    manualURLText = ""
                }
                Button("Отмена", role: .cancel) { manualURLText = "" }
            } message: {
                Text("Вставьте ссылку из плеера, если он её показывает.")
            }
            .overlay {
                if showCinemarDiag {
                    cinemarDiagOverlay
                }
            }
        }
    }

    // MARK: - Диагностика cinemar

    private var cinemarDiagOverlay: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Структура cinemar")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = cinemarDiagText
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(.white)
                    }
                }

                Text("Скопируй и пришли весь текст ниже")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))

                ScrollView {
                    Text(cinemarDiagText.isEmpty ? "Пусто. Cinemar-iframe не ответил (возможно, не загрузился)." : cinemarDiagText)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = cinemarDiagText
                        showCinemarDiag = false
                    } label: {
                        Text("Скопировать и закрыть")
                            .font(.subheadline).bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    Button {
                        showCinemarDiag = false
                    } label: {
                        Text("Закрыть")
                            .font(.subheadline).bold()
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(Color.white.opacity(0.15))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(20)
            .background(Color(white: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(20)
        }
    }

    private func runCinemarDiagnostics() {
        cinemarDiagText = "Собираю данные из cinemar-iframe…"
        showCinemarDiag = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let window = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first?
                    .windows
                    .first(where: { $0.isKeyWindow }),
                  let webView = findWebView(in: window) else {
                cinemarDiagText = "WKWebView не найден"
                return
            }

            let js = """
            (function(){
            try{window.postMessage({type:'diagnose'},'*');}catch(e){}
            var frames=document.querySelectorAll('iframe');
            for(var i=0;i<frames.length;i++){
            try{frames[i].contentWindow.postMessage({type:'diagnose'},'*');}catch(e){}
            }
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    private func findWebView(in view: UIView) -> WKWebView? {
        if let wv = view as? WKWebView { return wv }
        for sub in view.subviews {
            if let found = findWebView(in: sub) { return found }
        }
        return nil
    }

    private func presentShareSheet(for url: URL) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let pop = activity.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX,
                                    y: top.view.bounds.midY,
                                    width: 1, height: 1)
            pop.permittedArrowDirections = []
        }
        top.present(activity, animated: true, completion: nil)
    }

    static func normalizeVideoURL(_ url: URL) -> URL {
        let s = url.absoluteString
        if let r = s.range(of: ":hls:") {
            let trimmed = String(s[..<r.lowerBound])
            if let u = URL(string: trimmed) { return u }
        }
        return url
    }
}
