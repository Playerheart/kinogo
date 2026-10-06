import SwiftUI

struct CaptureSheetView: View {
    let videoURL: URL?
    let voices: [String]
    let currentVoice: String?

    var onVoiceChange: (String) -> Void
    var onOpenInSafari: (URL) -> Void
    var onShare: (URL) -> Void
    var onCopy: (URL) -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                if let url = videoURL {
                    Section("Ссылка на видео") {
                        Text(url.absoluteString)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(8)
                    }
                }

                if !voices.isEmpty {
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

                if let url = videoURL {
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
            }
        }
    }
}
