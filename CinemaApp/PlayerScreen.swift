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

    @State private var capturedVideoURL: URL?
    @State private var showCaptureSheet = false
    @State private var lastCaptureTime: Date = .distantPast

    @State private var showManualURLInput = false
    @State private var manualURLText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                // WKWebView: скрыт, но остаётся в иерархии — он источник
                // всех запросов к cinemar. Через JS hunter ловит .mp4/.m3u8.
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
                    .opacity(0)
                    .allowsHitTesting(false)
                    .edgesIgnoringSafeArea(.all)
                }

                // Видимый слой — вместо плеера
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
                    onVoiceChange: { v in
                        currentVoice = v
                        pendingVoice = v
                        capturedVideoURL = nil
                        showCaptureSheet = false
                    },
                    onOpenInSafari: { url in
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
                        // «Отмена» в sheet = закрыть sheet + вернуться к описанию фильма
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
        }
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
