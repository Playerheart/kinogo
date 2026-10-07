import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var hostInput: String = AppConfig.host
    @State private var debugTitle: String = ""
    @State private var debugMessage: String = ""
    @State private var showDebug = false

    @State private var redirectHost: String? = nil
    @State private var compatReport: CompatReport? = nil
    @State private var isChecking = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Адрес сайта") {
                    TextField("kinogo.family", text: $hostInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    Button {
                        saveTapped()
                    } label: {
                        HStack {
                            Label("Сохранить и переключиться", systemImage: "checkmark")
                            if isChecking {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(hostInput.trimmingCharacters(in: .whitespaces).isEmpty || isChecking)

                    Button {
                        checkCompatibilityTapped()
                    } label: {
                        HStack {
                            Label("Проверить совместимость", systemImage: "checkmark.shield")
                            if isChecking {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(hostInput.trimmingCharacters(in: .whitespaces).isEmpty || isChecking)

                    Button(role: .destructive) {
                        AppConfig.resetToDefault()
                        hostInput = AppConfig.defaultHost
                        NotificationCenter.default.post(name: .appConfigChanged, object: nil)
                    } label: {
                        Label("Сбросить на \(AppConfig.defaultHost)", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(isChecking)
                }

                Section("Диагностика") {
                    Button {
                        runNetworkDiagnostics()
                    } label: {
                        Label("Проверить сеть", systemImage: "stethoscope")
                    }
                    .disabled(isChecking)

                    Button {
                        checkRedirect()
                    } label: {
                        HStack {
                            Label("Проверить переадресацию", systemImage: "arrow.triangle.branch")
                            if isChecking {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isChecking)
                }

                Section("Профиль парсинга") {
                    HStack {
                        Text("Хост")
                        Spacer()
                        Text(AppConfig.host).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Источник")
                        Spacer()
                        Text(AppConfig.profileSourceLabel)
                            .foregroundStyle(
                                AppConfig.hasCachedProfileForCurrentHost ? .green :
                                (AppConfig.hasBuiltInProfileForCurrentHost ? .blue : .secondary)
                            )
                    }

                    Button {
                        runInference()
                    } label: {
                        HStack {
                            Label("Определить профиль", systemImage: "wand.and.stars")
                            if isChecking {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isChecking)

                    Button(role: .destructive) {
                        AppConfig.clearCachedProfile(for: AppConfig.host)
                        NotificationCenter.default.post(name: .appConfigChanged, object: nil)
                    } label: {
                        Label("Сбросить профиль для \(AppConfig.host)", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(!AppConfig.hasCachedProfileForCurrentHost || isChecking)

                    if !AppConfig.cachedProfileHosts.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Настроенные хосты:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(AppConfig.cachedProfileHosts.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Текущий конфиг") {
                    HStack {
                        Text("Хост")
                        Spacer()
                        Text(AppConfig.host).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Referer")
                        Spacer()
                        Text(AppConfig.referer)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    if let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                       let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        HStack {
                            Text("Версия")
                            Spacer()
                            Text("\(v) (build \(b))").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .overlay {
                if showDebug {
                    debugOverlay
                }
            }
            .overlay {
                if let report = compatReport {
                    compatOverlay(report: report)
                }
            }
        }
    }

    // MARK: - Сохранение с проверкой

    private func saveTapped() {
        let clean = cleanHost(hostInput)

        if clean == AppConfig.host {
            dismiss()
            return
        }

        isChecking = true
        debugTitle = "Проверка совместимости"
        debugMessage = "▶ Анализирую \(clean)…"
        showDebug = true

        CompatibilityChecker.check(host: clean) { report in
            DispatchQueue.main.async {
                self.isChecking = false
                self.showDebug = false
                self.redirectHost = clean
                self.compatReport = report
            }
        }
    }

    // MARK: - Просто проверить совместимость (без переключения)

    private func checkCompatibilityTapped() {
        let clean = cleanHost(hostInput)
        guard !clean.isEmpty else { return }

        isChecking = true
        debugTitle = "Проверка совместимости"
        debugMessage = "▶ Анализирую \(clean)…"
        showDebug = true

        CompatibilityChecker.check(host: clean) { report in
            DispatchQueue.main.async {
                self.isChecking = false
                self.showDebug = false
                self.redirectHost = nil
                self.compatReport = report
            }
        }
    }

    private func cleanHost(_ raw: String) -> String {
        return raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    // MARK: - Определение профиля

    private func runInference() {
        isChecking = true
        debugTitle = "Определение профиля"
        debugMessage = "▶ Открываю \(AppConfig.host)…\nОбычно занимает 30–60 секунд."
        showDebug = true

        let targetHost = AppConfig.host
        ProfileInferencer.shared.infer(host: targetHost) { result in
            DispatchQueue.main.async {
                self.isChecking = false

                guard let r = result else {
                    self.debugTitle = "❌ Не удалось"
                    self.debugMessage = "Инференсер не вернул результат."
                    return
                }

                if r.movieCount > 0 {
                    AppConfig.cacheProfile(r.profile, for: r.host)
                    self.debugTitle = "✅ Профиль определён"
                    self.debugMessage = """
                    Хост: \(r.host)
                    Найдено фильмов: \(r.movieCount)

                    \(r.log)
                    """
                    NotificationCenter.default.post(name: .appConfigChanged, object: nil)
                } else {
                    self.debugTitle = "❌ Не удалось"
                    self.debugMessage = """
                    Не получилось подобрать селекторы для \(targetHost).

                    Лог:
                    \(r.log)
                    """
                }
            }
        }
    }

    // MARK: - Диагностика сети

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
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 420)
                .padding(10)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = debugMessage
                    } label: {
                        Text("Скопировать")
                            .font(.subheadline).bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.15))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }

                    Button {
                        showDebug = false
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
            }
            .padding(20)
            .background(Color(white: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(24)
        }
    }

    // MARK: - Отчёт о совместимости

    private func compatOverlay(report: CompatReport) -> some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {

                Text(report.verdictTitle)
                    .font(.headline)
                    .foregroundStyle(verdictColor(report.verdict))

                Text("Хост: \(report.host)")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))

                Text("Профиль: \(report.profileSource)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))

                Text(report.verdictMessage)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)

                ScrollView {
                    Text(report.detailsText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 320)
                .padding(10)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = report.detailsText
                    } label: {
                        Text("Скопировать")
                            .font(.subheadline).bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.15))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }

                    if let rh = redirectHost {
                        // Сценарий «Сохранить и переключиться» — показываем кнопку
                        Button {
                            AppConfig.host = rh
                            hostInput = rh
                            NotificationCenter.default.post(name: .appConfigChanged, object: nil)
                            compatReport = nil
                            redirectHost = nil
                            dismiss()
                        } label: {
                            Text("Переключиться")
                                .font(.subheadline).bold()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(report.verdict == .incompatible ? Color.red : Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }

                    Button {
                        compatReport = nil
                        redirectHost = nil
                        hostInput = AppConfig.host
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
            }
            .padding(20)
            .background(Color(white: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(24)
        }
    }

    private func verdictColor(_ v: CompatReport.Verdict) -> Color {
        switch v {
        case .full:         return .green
        case .partial:      return .yellow
        case .incompatible: return .red
        }
    }

    // MARK: - Функции

    private func runNetworkDiagnostics() {
        debugTitle = "Диагностика сети"
        debugMessage = "▶ Тестирую три URL…"
        showDebug = true

        var results: [String] = []
        let lock = NSLock()
        let group = DispatchGroup()

        let tests: [(String, URL, Bool)] = [
            ("google.com",       URL(string: "https://www.google.com/")!, false),
            (AppConfig.host,     AppConfig.baseURL,                     false),
            ("host.cinemap.cc",  URL(string: "https://host.cinemap.cc/")!, true)
        ]

        for (name, testURL, showBody) in tests {
            group.enter()
            var req = URLRequest(url: testURL,
                                 cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: 8)
            req.setValue(AppConfig.referer, forHTTPHeaderField: "Referer")
            req.setValue(AppConfig.origin,  forHTTPHeaderField: "Origin")
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
                        let preview = String(data: d.prefix(300), encoding: .utf8) ?? "<бинарные данные>"
                        block += "\n\n   ПРЕВЬЮ:\n\(preview)"
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
    }

    private func checkRedirect() {
        isChecking = true

        var req = URLRequest(url: AppConfig.baseURL,
                             cachePolicy: .reloadIgnoringLocalCacheData,
                             timeoutInterval: 12)
        req.httpMethod = "GET"
        req.setValue(AppConfig.referer, forHTTPHeaderField: "Referer")
        req.setValue(AppConfig.origin,  forHTTPHeaderField: "Origin")

        URLSession.shared.dataTask(with: req) { _, response, error in
            DispatchQueue.main.async {
                self.isChecking = false

                if let err = error as NSError? {
                    self.debugTitle = "Переадресация"
                    self.debugMessage = """
                    ❌ Ошибка проверки
                    \(err.domain)#\(err.code)
                    \(err.localizedDescription)
                    """
                    self.showDebug = true
                    return
                }
                guard let finalURL = response?.url else {
                    self.debugTitle = "Переадресация"
                    self.debugMessage = "Не удалось получить финальный URL"
                    self.showDebug = true
                    return
                }
                let finalHost = finalURL.host ?? ""
                let currentHost = AppConfig.host

                if finalHost.isEmpty || finalHost == currentHost {
                    self.debugTitle = "Переадресация"
                    self.debugMessage = """
                    ✅ Переадресации нет

                    Адрес: \(currentHost)
                    Финальный: \(finalHost.isEmpty ? "—" : finalHost)
                    """
                    self.showDebug = true
                    return
                }

                self.redirectHost = finalHost
                self.debugTitle = "Проверка совместимости"
                self.debugMessage = "▶ Анализирую \(finalHost)…"
                self.showDebug = true

                CompatibilityChecker.check(host: finalHost) { report in
                    DispatchQueue.main.async {
                        self.showDebug = false
                        self.compatReport = report
                    }
                }
            }
        }.resume()
    }
}
