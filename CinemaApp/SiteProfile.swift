import Foundation

struct SiteProfile: Codable, Equatable {
    // MARK: - Каталог
    var catalogCard: String
    var catalogTitleLink: String
    var catalogPosterImg: String
    var catalogRating: String
    var catalogInfoSpans: String
    var catalogYearFromTitle: Bool
    var catalogMaxCards: Int

    // MARK: - Детальная
    var detailH1: String
    var detailPosterImg: String
    var detailInfoSpans: String
    var detailFDop: String
    var detailDescription: String
    var detailActorsContainer: String
    var detailPlayersTabs: String
    var detailPlayersContainer: String
    var detailRelated: String

    // MARK: - Общее
    var movieURLRegex: String
    var playerHosts: [String]

    static let `default` = SiteProfile(
        catalogCard: ".shortStory",
        catalogTitleLink: ".sHead h2 a, h2 a",
        catalogPosterImg: ".sPoster img",
        catalogRating: ".ratingStats",
        catalogInfoSpans: ".sInfo span",
        catalogYearFromTitle: true,
        catalogMaxCards: 200,

        detailH1: ".pad.sHead h1, .sHead h1, h1",
        detailPosterImg: ".shortStoryBody .sPoster img, .fullStory .sPoster img, .sPoster img",
        detailInfoSpans: ".shortStoryBody .sInfo span",
        detailFDop: ".fDop > div",
        detailDescription: ".filmDescription p",
        detailActorsContainer: ".cast .sInfo span",
        detailPlayersTabs: ".js-player-tabs li[data-src], .player-tabs li[data-src]",
        detailPlayersContainer: ".js-player-container iframe, iframe",
        detailRelated: ".viewMore-wrap .relatedItem a, .viewMore .relatedItem a",

        movieURLRegex: "/\\d+-[a-z0-9\\-]+\\.html",
        playerHosts: ["cinemar","kodik","alloha","bazon","videocdn","sibnet","aniboom","hdvb","vadbam","pleer"]
    )

    /// Встроенные профили для известных зеркал на DLE-теме kinogo.
    static let builtIn: [String: SiteProfile] = [
        "kinogo.family":  .default,
        "kinogo.luxury":  .default,
        "kinogo.biz":     .default,
        "kinogo.mu":      .default,
        "mix.kinogo.mu":  .default,
    ]

    var jsonString: String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(self),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }

    static func from(json: String) -> SiteProfile? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(SiteProfile.self, from: data)
    }
}
