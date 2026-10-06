import SwiftUI
import Foundation

struct CaptureSheetView: View {
    let videoURL: URL?
    let voices: [String]
    let currentVoice: String?

    var onVoiceChange: (String) -> Void
    var onOpenInSafari: (URL) -> Void
    var onShare: (URL) -> Void
    var onCopy: (URL) -> Void
    var onCancel: () -> Void

    @State private var debugTitle: String = ""
    @State private var debugMessage: String = ""
    @State private var showDebugOverlay = false

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
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        if let url = videoURL {
                            debugFetch(url)
                        }
                    } label: {
                        Image(systemName: "stethoscope")
                    }
                    .disabled(videoURL == nil)
                }
            }
            .overlay {
                if showDebugOverlay {
                    debugOverlay
                }
            }
        }
    }

    private var debugOverlay: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
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
                .frame(maxHeight: 420)
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

    private func debugFetch(_ url: URL) {
        debugTitle = "Диагностика сети"
        debugMessage = "▶ Тестирую три URL…"
        showDebugOverlay = true

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
}
