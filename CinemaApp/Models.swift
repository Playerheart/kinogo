import Foundation

struct Movie: Identifiable, Codable, Hashable {
    var id: String { url }
    let title: String
    let url: String
    let poster: String
    let year: String
    let rating: String
}

struct Player: Identifiable, Codable, Hashable {
    var id: String { url + "|" + name }
    let name: String
    let url: String
}

struct DownloadOption: Identifiable, Codable, Hashable {
    var id: String { url }
    let quality: String
    let url: String
}

struct MovieDetail: Codable {
    let title: String
    let description: String
    let poster: String
    let players: [Player]
    let downloads: [DownloadOption]
}

enum ParserError: LocalizedError {
    case cancelled, timeout, jsError(String), invalidResult, noData

    var errorDescription: String? {
        switch self {
        case .cancelled: return "Отменено"
        case .timeout: return "Превышено время ожидания"
        case .jsError(let s): return "Ошибка скрипта: \(s)"
        case .invalidResult: return "Неверный формат данных"
        case .noData: return "Данные не найдены"
        }
    }
}
