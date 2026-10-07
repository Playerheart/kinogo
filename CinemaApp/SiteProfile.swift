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

    /// Встроенный профиль для kinogo2026.com (шаблон smartphone с .article / .persons / .relatednews).
    static let kinogo2026 = SiteProfile(
        catalogCard: ".article",
        catalogTitleLink: "h2.article__title a",
        catalogPosterImg: "a.article__poster img",
        catalogRating: ".rating__votes",
        catalogInfoSpans: ".article__info > div",
        catalogYearFromTitle: true,
        catalogMaxCards: 300,

        detailH1: ".fullstory__title h1, h1",
        detailPosterImg: "a.article__poster img, .article__poster img",
        detailInfoSpans: ".article__info > div",
        detailFDop: ".article__info > div",
        detailDescription: ".description__block, .article__text",
        detailActorsContainer: ".persons__list a.js-person, .persons__list a.persons__item",
        detailPlayersTabs: ".js-player-tabs li[data-src], .player-tabs li[data-src], li[data-src]",
        detailPlayersContainer: ".js-player-container iframe, iframe",
        detailRelated: ".relatednews__content a.relatednews__item",

        movieURLRegex: "/\\d+-[a-z0-9\\-]+\\.html",
        playerHosts: ["cinemar","kodik","alloha","bazon","videocdn","sibnet","aniboom","hdvb","vadbam","pleer"]
    )

    static let builtIn: [String: SiteProfile] = [
        "kinogo.family":  .default,
        "kinogo.luxury":  .default,
        "kinogo.biz":     .default,
        "kinogo.mu":      .default,
        "mix.kinogo.mu":  .default,
        "kinogo2026.com": .kinogo2026,
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
