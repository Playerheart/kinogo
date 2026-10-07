import Foundation

enum AppConfig {
    private static let hostKey = "AppConfig.host"
    private static let cachedProfilesKey = "AppConfig.cachedProfiles"
    static let defaultHost = "kinogo.family"

    // MARK: - Host

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

    // MARK: - Кэш профилей (автоподбор + ручные правки)

    static var cachedProfiles: [String: SiteProfile] {
        get {
            guard let data = UserDefaults.standard.data(forKey: cachedProfilesKey),
                  let dict = try? JSONDecoder().decode([String: SiteProfile].self, from: data)
            else { return [:] }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: cachedProfilesKey)
            }
        }
    }

    /// Приоритет: кэш → встроенный → дефолт.
    static var profile: SiteProfile {
        if let cached = cachedProfiles[host] { return cached }
        if let built = SiteProfile.builtIn[host] { return built }
        return SiteProfile.default
    }

    static func cacheProfile(_ p: SiteProfile, for host: String) {
        var dict = cachedProfiles
        dict[host] = p
        cachedProfiles = dict
    }

    static func clearCachedProfile(for host: String) {
        var dict = cachedProfiles
        dict.removeValue(forKey: host)
        cachedProfiles = dict
    }

    static var hasCachedProfileForCurrentHost: Bool {
        cachedProfiles[host] != nil
    }

    static var hasBuiltInProfileForCurrentHost: Bool {
        SiteProfile.builtIn[host] != nil
    }

    static var profileSourceLabel: String {
        if hasCachedProfileForCurrentHost { return "Подобран автоматически" }
        if hasBuiltInProfileForCurrentHost { return "Встроенный" }
        return "По умолчанию"
    }

    static var cachedProfileHosts: [String] {
        cachedProfiles.keys.sorted()
    }
}
