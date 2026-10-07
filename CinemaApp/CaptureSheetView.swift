import SwiftUI
import Foundation

struct CaptureSheetView: View {
    let videoURL: URL?
    let voices: [String]
    let currentVoice: String?

    let seasons: [String]
    let episodes: [String]
    let currentSeason: String?
    let currentEpisode: String?

    @Binding var cinemarDiagText: String
    var onRequestCinemarDiag: () -> Void

    var onVoiceChange: (String) -> Void
    var onSeasonChange: (String) -> Void
    var onEpisodeChange: (String) -> Void
    var onOpenInSafari: (URL) -> Void
    var onShare: (URL) -> Void
    var onCopy: (URL) -> Void
    var onCancel: () -> Void

    @State private var showDiagOverlay = false

    var body: some View {
        NavigationStack {
            Form {
                if seasons.count > 1 {
                    Section("Сезон") {
                        Picker("Сезон", selection: Binding(
                            get: { currentSeason ?? seasons.first ?? "" },
                            set: { newVal in
                                if newVal != currentSeason { onSeasonChange(newVal) }
                            }
                        )) {
                            ForEach(seasons, id: \.self) { s in Text(s).tag(s) }
                        }
                        .pickerStyle(.menu)
                    }
                }

                if episodes.count > 1 {
                    Section("Серия") {
                        Picker("Серия", selection: Binding(
                            get: { currentEpisode ?? episodes.first ?? "" },
                            set: { newVal in
                                if newVal != currentEpisode { onEpisodeChange(newVal) }
                            }
                        )) {
                            ForEach(episodes, id: \.self) { e in Text(e).tag(e) }
                        }
                        .pickerStyle(.menu)
                    }
                }

                if voices.count > 1 {
                    Section("Озвучка") {
                        Picker("Озвучка", selection: Binding(
                            get: { currentVoice ?? voices.first ?? "" },
                            set: { newVal in
                                if newVal != currentVoice { onVoiceChange(newVal) }
                            }
                        )) {
                            ForEach(voices, id: \.self) { v in Text(v).tag(v) }
                        }
                        .pickerStyle(.menu)
                    }
                }

                if videoURL == nil && (seasons.count > 1 || episodes.count > 1 || voices.count > 1) {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Text("Загружаю ссылку…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                }

                if let url = videoURL {
                    Section("Ссылка на видео") {
                        Text(url.absoluteString)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(8)
                    }

                    Section {
                        Button {
                            onOpenInSafari(url)
                        } label: {
                            Label("Открыть в Safari", systemImage: "safari")
                        }
                        Button {
                            onShare(url)
                        } label: {
                            Label("Поделиться ссылкой", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            onCopy(url)
                        } label: {
                            Label("Скопировать ссылку", systemImage: "doc.on.doc")
                        }
                    }
                }
            }
            .navigationTitle("Ссылка на видео")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        // Запускаем cinemar-диагностику на стороне PlayerScreen
                        // и открываем overlay здесь, в sheet.
                        onRequestCinemarDiag()
                        showDiagOverlay = true
                    } label: {
                        Image(systemName: "stethoscope")
                    }
                }
            }
            .overlay {
                if showDiagOverlay {
                    cinemarDiagOverlay
                }
            }
        }
    }

    // MARK: - Оверлей cinemar-диагностики

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
                    Text(cinemarDiagText.isEmpty
                         ? "Пусто. Cinemar-iframe не ответил (возможно, не загрузился)."
                         : cinemarDiagText)
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
                        showDiagOverlay = false
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
                        showDiagOverlay = false
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
}
