import Foundation

enum AppConfig {
    private static let hostKey = "AppConfig.host"
    static let defaultHost = "kinogo.family"

    static var host: String {
        get {
            UserDefaults.standard.string(forKey: hostKey) ?? defaultHost
        }
        set {
            let clean = newValue
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            UserDefaults.standard.set(clean, forKey: hostKey)
        }
    }

    static var baseURL: URL {
        URL(string: "https://\(host)/") ?? URL(string: "https://\(defaultHost)/")!
    }

    static func url(_ path: String) -> URL? {
        let normalized = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return URL(string: "https://\(host)/\(normalized)")
    }

    static var referer: String { "https://\(host)/" }
    static var origin: String { "https://\(host)" }

    static func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: hostKey)
    }
}
