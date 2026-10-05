import Foundation

struct Movie: Identifiable, Codable, Hashable {
    var id: String { url }
    let title: String
    let url: String
    let poster: String
    let year: String
    let rating: String
}

struct Actor: Identifiable, Codable, Hashable {
    var id: String { name + photo }
    let name: String
    let photo: String
}

struct MovieDetail: Codable {
    let title: String
    let poster: String
    let description: String
    let players: [Player]
    let actors: [Actor]
}

struct Player: Identifiable, Codable, Hashable {
    var id: String { url }
    let name: String
    let url: String
}

enum ParserError: LocalizedError {
    case cancelled, timeout, jsError(String), invalidResult, noData
    var errorDescription: String? {
        switch self {
        case .cancelled: return "Отменено"
        case .timeout: return "Превышено время ожидания"
        case .jsError(let s): return "Ошибка: \(s)"
        case .invalidResult: return "Неверный формат данных"
        case .noData: return "Данные не найдены"
        }
    }
}
