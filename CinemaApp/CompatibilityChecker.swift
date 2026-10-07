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
            return "Сайт использует ту же архитектуру. Можно безопасно переключиться."
        case .partial:
            return "Часть функций может не работать: например, актёры, рекомендации или плеер. Переключиться?"
        case .incompatible:
            return "Другая архитектура сайта. Переключение сломает парсинг каталога, карточек и плеера. Рекомендуется отмена."
        }
    }

    var detailsText: String {
        var lines: [String] = []
        lines.append("Хост: \(host)")
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

    static func check(host: String, completion: @escaping (CompatReport) -> Void) {
        var checks: [CompatCheck] = []
        guard let base = URL(string: "https://\(host)/") else {
            completion(CompatReport(host: host, checks: []))
            return
        }

        var rootReq = URLRequest(url: base,
                                 cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: 12)
        rootReq.setValue("https://\(host)/", forHTTPHeaderField: "Referer")
        rootReq.setValue("https://\(host)",  forHTTPHeaderField: "Origin")

        URLSession.shared.dataTask(with: rootReq) { data, response, error in

            if let err = error as NSError? {
                checks.append(.init(name: "HTTP-ответ",
                                    status: .fail,
                                    detail: "\(err.domain)#\(err.code)  \(err.localizedDescription)"))
                completion(CompatReport(host: host, checks: checks))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                checks.append(.init(name: "HTTP-ответ", status: .fail, detail: "Нет ответа"))
                completion(CompatReport(host: host, checks: checks))
                return
            }
            let httpOK = (200...299).contains(http.statusCode)
            checks.append(.init(name: "HTTP-ответ",
                                status: httpOK ? .ok : .fail,
                                detail: "HTTP \(http.statusCode)"))

            let html = String(data: data ?? Data(), encoding: .utf8) ?? ""

            let moviePattern = try? NSRegularExpression(pattern: #"/\d+-[a-z0-9\-]+\.html"#,
                                                        options: .caseInsensitive)
            let foundMovie = moviePattern?.firstMatch(in: html,
                                                      range: NSRange(html.startIndex..., in: html)) != nil
            checks.append(.init(name: "URL-паттерн /NNN-slug.html",
                                status: foundMovie ? .ok : .fail,
                                detail: foundMovie ? "Найден" : "Не найден"))

            let hasShortstory = html.contains("shortstory")
            checks.append(.init(name: "Разметка .shortstory",
                                status: hasShortstory ? .ok : .warn,
                                detail: hasShortstory ? "Есть" : "Нет"))

            var firstMoviePath: String? = nil
            if let regex = moviePattern,
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let r = Range(match.range, in: html) {
                firstMoviePath = String(html[r])
            }

            guard let path = firstMoviePath,
                  let movieURL = URL(string: "https://\(host)\(path)") else {
                completion(CompatReport(host: host, checks: checks))
                return
            }

            var detailReq = URLRequest(url: movieURL,
                                       cachePolicy: .reloadIgnoringLocalCacheData,
                                       timeoutInterval: 12)
            detailReq.setValue("https://\(host)/", forHTTPHeaderField: "Referer")

            URLSession.shared.dataTask(with: detailReq) { ddata, dresponse, _ in

                // ФИКС (п.6): 9-я проверка — HTTP-статус detail-страницы.
                let dhttp = dresponse as? HTTPURLResponse
                let detailStatus = dhttp?.statusCode ?? -1
                let detailOK = (200...299).contains(detailStatus)
                checks.append(.init(name: "HTTP detail-страницы",
                                    status: detailOK ? .ok : .fail,
                                    detail: "HTTP \(detailStatus)"))

                let dhtml = String(data: ddata ?? Data(), encoding: .utf8) ?? ""

                let hasJSONLD = dhtml.contains("\"@type\"") && dhtml.contains("Movie")
                checks.append(.init(name: "JSON-LD Movie",
                                    status: hasJSONLD ? .ok : .warn,
                                    detail: hasJSONLD ? "Найден" : "Нет (сработает HTML-fallback)"))

                let hasPersons = dhtml.contains("persons__section")
                checks.append(.init(name: "Актёры (.persons__section)",
                                    status: hasPersons ? .ok : .fail,
                                    detail: hasPersons ? "Есть" : "Нет"))

                let hasRelated = dhtml.contains("relatednews__item")
                checks.append(.init(name: "Рекомендации (.relatednews__item)",
                                    status: hasRelated ? .ok : .warn,
                                    detail: hasRelated ? "Есть" : "Нет"))

                let hasCinemar = dhtml.lowercased().contains("cinemar")
                checks.append(.init(name: "Плеер cinemar",
                                    status: hasCinemar ? .ok : .fail,
                                    detail: hasCinemar ? "Найден" : "Не найден"))

                let hasPlayerTabs = dhtml.contains("js-player-tabs")
                    || dhtml.contains("player-tabs")
                    || dhtml.contains("data-src")
                checks.append(.init(name: "Плеер-табы / озвучки",
                                    status: hasPlayerTabs ? .ok : .warn,
                                    detail: hasPlayerTabs ? "Есть" : "Нет"))

                completion(CompatReport(host: host, checks: checks))
            }.resume()
        }.resume()
    }
}
