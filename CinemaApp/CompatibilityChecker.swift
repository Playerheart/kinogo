import Foundation

struct CompatCheck: Identifiable {
    enum Status { case ok, warn, fail }
    let id = UUID()
    let name: String
    let status: Status
    let detail: String

    var icon: String {
        switch status {
        case .ok:   return "✅"
        case .warn: return "⚠️"
        case .fail: return "❌"
        }
    }
}

struct CompatReport {
    let host: String
    let profileSource: String
    let checks: [CompatCheck]

    var okCount: Int   { checks.filter { $0.status == .ok   }.count }
    var warnCount: Int { checks.filter { $0.status == .warn }.count }
    var failCount: Int { checks.filter { $0.status == .fail }.count }

    enum Verdict { case full, partial, incompatible }

    var verdict: Verdict {
        if failCount == 0 && warnCount == 0 { return .full }
        if failCount == 0                   { return .partial }
        if failCount >= 2                   { return .incompatible }
        return .partial
    }

    var verdictTitle: String {
        switch verdict {
        case .full:         return "Полностью совместимо"
        case .partial:      return "Совместимо частично"
        case .incompatible: return "Не совместимо"
        }
    }

    var verdictMessage: String {
        switch verdict {
        case .full:
            return "Сайт использует ту же архитектуру. Можно безопасно переключаться."
        case .partial:
            return "Часть функций может не работать. Попробуйте «Определить профиль» — если поможет, повторите проверку."
        case .incompatible:
            return "Другая архитектура сайта или профиль не подходит. Сначала определите профиль, потом проверьте заново."
        }
    }

    var detailsText: String {
        var lines: [String] = []
        lines.append("Хост: \(host)")
        lines.append("Профиль: \(profileSource)")
        lines.append("Проверок: \(checks.count)   ✅\(okCount)  ⚠️\(warnCount)  ❌\(failCount)")
        lines.append("")
        for c in checks {
            lines.append("\(c.icon)  \(c.name)")
            lines.append("     \(c.detail)")
        }
        return lines.joined(separator: "\n")
    }
}

enum CompatibilityChecker {

    // Десктопный UA — как у инференсера, иначе мобильная версия отдаёт урезанный HTML
    private static let desktopUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    static func check(host: String, completion: @escaping (CompatReport) -> Void) {
        // Используем профиль хоста: если это текущий хост — из AppConfig,
        // иначе встроенный или дефолтный.
        let profile: SiteProfile
        let profileSource: String
        if host == AppConfig.host {
            profile = AppConfig.profile
            profileSource = AppConfig.profileSourceLabel
        } else if let built = SiteProfile.builtIn[host] {
            profile = built
            profileSource = "Встроенный"
        } else {
            profile = SiteProfile.default
            profileSource = "По умолчанию"
        }

        var checks: [CompatCheck] = []
        guard let base = URL(string: "https://\(host)/") else {
            completion(CompatReport(host: host, profileSource: profileSource, checks: []))
            return
        }

        var rootReq = URLRequest(url: base,
                                 cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: 12)
        rootReq.setValue("https://\(host)/", forHTTPHeaderField: "Referer")
        rootReq.setValue("https://\(host)",  forHTTPHeaderField: "Origin")
        rootReq.setValue(desktopUA, forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: rootReq) { data, response, error in
            if let err = error as NSError? {
                checks.append(.init(name: "HTTP-ответ",
                                    status: .fail,
                                    detail: "\(err.domain)#\(err.code)  \(err.localizedDescription)"))
                completion(CompatReport(host: host, profileSource: profileSource, checks: checks))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                checks.append(.init(name: "HTTP-ответ", status: .fail, detail: "Нет ответа"))
                completion(CompatReport(host: host, profileSource: profileSource, checks: checks))
                return
            }
            let httpOK = (200...299).contains(http.statusCode)
            checks.append(.init(name: "HTTP-ответ",
                                status: httpOK ? .ok : .fail,
                                detail: "HTTP \(http.statusCode)"))

            let html = String(data: data ?? Data(), encoding: .utf8) ?? ""

            // ---- URL-паттерн карточек ----
            var foundMoviePath: String? = nil
            if let regex = try? NSRegularExpression(pattern: profile.movieURLRegex, options: .caseInsensitive) {
                let ns = html as NSString
                let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
                let count = matches.count
                if let m = matches.first, m.numberOfRanges >= 1 {
                    foundMoviePath = ns.substring(with: m.range)
                }
                let st: CompatCheck.Status = count >= 10 ? .ok : (count >= 1 ? .warn : .fail)
                checks.append(.init(name: "URL карточек (\(shortRegex(profile.movieURLRegex)))",
                                    status: st,
                                    detail: "Найдено \(count) ссылок"))
            } else {
                checks.append(.init(name: "URL карточек", status: .warn, detail: "Невалидная регулярка"))
            }

            // ---- Класс карточки каталога ----
            let cardClasses = extractClasses(from: profile.catalogCard)
            if !cardClasses.isEmpty {
                let found = cardClasses.first { html.contains($0) }
                checks.append(.init(name: "Каталог: класс (\(cardClasses.prefix(3).joined(separator: ", ")))",
                                    status: found != nil ? .ok : .fail,
                                    detail: found != nil ? "Найден: \(found!)" : "Не найден в HTML главной"))
            }

            // ---- Title-link и poster-img селекторы ----
            let titleClasses = extractClasses(from: profile.catalogTitleLink)
            if !titleClasses.isEmpty {
                let found = titleClasses.first { html.contains($0) }
                checks.append(.init(name: "Каталог: title (\(titleClasses.prefix(2).joined(separator: ", ")))",
                                    status: found != nil ? .ok : .warn,
                                    detail: found != nil ? "Найден: \(found!)" : "Не найден"))
            }
            let posterClasses = extractClasses(from: profile.catalogPosterImg)
            if !posterClasses.isEmpty {
                let found = posterClasses.first { html.contains($0) }
                checks.append(.init(name: "Каталог: poster (\(posterClasses.prefix(2).joined(separator: ", ")))",
                                    status: found != nil ? .ok : .warn,
                                    detail: found != nil ? "Найден: \(found!)" : "Не найден"))
            }

            // ---- Идём на детальную ----
            guard let path = foundMoviePath,
                  let movieURL = URL(string: "https://\(host)\(path.hasPrefix("/") ? path : "/\(path)")") else {
                completion(CompatReport(host: host, profileSource: profileSource, checks: checks))
                return
            }

            var detailReq = URLRequest(url: movieURL,
                                       cachePolicy: .reloadIgnoringLocalCacheData,
                                       timeoutInterval: 12)
            detailReq.setValue("https://\(host)/", forHTTPHeaderField: "Referer")
            detailReq.setValue(desktopUA, forHTTPHeaderField: "User-Agent")

            URLSession.shared.dataTask(with: detailReq) { ddata, dresponse, _ in
                let dhttp = dresponse as? HTTPURLResponse
                let detailStatus = dhttp?.statusCode ?? -1
                let detailOK = (200...299).contains(detailStatus)
                checks.append(.init(name: "HTTP detail-страницы",
                                    status: detailOK ? .ok : .fail,
                                    detail: "HTTP \(detailStatus)"))

                let dhtml = String(data: ddata ?? Data(), encoding: .utf8) ?? ""

                // JSON-LD Movie
                let hasJSONLD = dhtml.contains("\"@type\"") && dhtml.contains("Movie")
                checks.append(.init(name: "JSON-LD Movie",
                                    status: hasJSONLD ? .ok : .warn,
                                    detail: hasJSONLD ? "Найден" : "Нет (fallback на HTML)"))

                // H1
                let h1Classes = extractClasses(from: profile.detailH1)
                let hasH1 = dhtml.contains("<h1") || h1Classes.contains { dhtml.contains($0) }
                checks.append(.init(name: "Детальная: H1",
                                    status: hasH1 ? .ok : .warn,
                                    detail: hasH1 ? "Есть" : "Нет"))

                // Poster
                let posterClasses2 = extractClasses(from: profile.detailPosterImg)
                let hasPoster = posterClasses2.contains { dhtml.contains($0) }
                checks.append(.init(name: "Детальная: постер (\(posterClasses2.prefix(2).joined(separator: ", ")))",
                                    status: hasPoster ? .ok : .warn,
                                    detail: hasPoster ? "Есть" : "Нет"))

                // Актёры
                let actorClasses = extractClasses(from: profile.detailActorsContainer)
                let hasCast = actorClasses.contains { dhtml.contains($0) }
                checks.append(.init(name: "Актёры (\(actorClasses.prefix(2).joined(separator: ", ")))",
                                    status: hasCast ? .ok : .fail,
                                    detail: hasCast ? "Есть" : "Нет"))

                // Описание
                let descClasses = extractClasses(from: profile.detailDescription)
                let hasDescription = descClasses.contains { dhtml.contains($0) }
                checks.append(.init(name: "Описание (\(descClasses.prefix(2).joined(separator: ", ")))",
                                    status: hasDescription ? .ok : .warn,
                                    detail: hasDescription ? "Есть" : "Нет"))

                // Рекомендации
                let relatedClasses = extractClasses(from: profile.detailRelated)
                let hasRelated = relatedClasses.contains { dhtml.contains($0) }
                checks.append(.init(name: "Рекомендации (\(relatedClasses.prefix(2).joined(separator: ", ")))",
                                    status: hasRelated ? .ok : .warn,
                                    detail: hasRelated ? "Есть" : "Нет"))

                // Плеер — по playerHosts
                var playerFound = false
                var playerHostFound = ""
                for ph in profile.playerHosts {
                    if dhtml.lowercased().contains(ph) {
                        playerFound = true
                        playerHostFound = ph
                        break
                    }
                }
                checks.append(.init(name: "Плеер (\(profile.playerHosts.prefix(3).joined(separator: "/")))",
                                    status: playerFound ? .ok : .fail,
                                    detail: playerFound ? "Найден: \(playerHostFound)" : "Нет"))

                // Плеер-табы
                let tabsClasses = extractClasses(from: profile.detailPlayersTabs)
                let hasTabs = tabsClasses.contains { dhtml.contains($0) } || dhtml.contains("data-src")
                checks.append(.init(name: "Плеер-табы / data-src",
                                    status: hasTabs ? .ok : .warn,
                                    detail: hasTabs ? "Есть" : "Нет"))

                completion(CompatReport(host: host, profileSource: profileSource, checks: checks))
            }.resume()
        }.resume()
    }

    // Извлекает имена классов из CSS-селектора
    // ".shortStory" -> ["shortStory"]
    // ".pad.sHead h1, .sHead h1, h1" -> ["pad", "sHead"]
    static func extractClasses(from selector: String) -> [String] {
        var out: [String] = []
        guard let regex = try? NSRegularExpression(pattern: "\\.([a-zA-Z_][a-zA-Z0-9_-]*)", options: []) else {
            return out
        }
        let ns = selector as NSString
        let matches = regex.matches(in: selector, range: NSRange(location: 0, length: ns.length))
        for m in matches where m.numberOfRanges >= 2 {
            let cls = ns.substring(with: m.range(at: 1))
            if !out.contains(cls) { out.append(cls) }
        }
        return out
    }

    private static func shortRegex(_ s: String) -> String {
        if s.count <= 24 { return s }
        let idx = s.index(s.startIndex, offsetBy: 24)
        return String(s[..<idx]) + "…"
    }
}
