import SwiftUI

@MainActor
final class MovieDetailViewModel: ObservableObject {
    @Published var detail: MovieDetail?
    @Published var isLoading = false
    @Published var errorText: String?
    @Published var selectedPlayer: Player?

    func load(_ movie: Movie) async {
        isLoading = true
        errorText = nil
        do {
            guard let url = URL(string: movie.url) else { throw ParserError.noData }
            let json = try await SiteParser.shared.extract(
                from: url,
                js: ExtractionScripts.detail(baseHost: AppConfig.host),
                waitAfterLoad: 4.0
            )
            guard let data = json.data(using: .utf8) else { throw ParserError.invalidResult }
            let d = try JSONDecoder().decode(MovieDetail.self, from: data)
            self.detail = d
            self.selectedPlayer = d.players.first
            if d.players.isEmpty && d.description.isEmpty {
                self.errorText = "Не удалось извлечь данные со страницы"
            }
        } catch {
            self.errorText = error.localizedDescription
        }
        isLoading = false
    }
}

struct MovieDetailView: View {
    let movie: Movie
    @StateObject private var vm = MovieDetailViewModel()
    @State private var showPlayer = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
        }
        .navigationTitle(vm.detail?.title.isEmpty == false ? vm.detail!.title : movie.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load(movie) }
        .fullScreenCover(isPresented: $showPlayer) {
            if let p = vm.selectedPlayer {
                PlayerScreen(player: p)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.detail == nil {
            ProgressView().tint(.white)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    header
                    metaLine

                    if let d = vm.detail, !d.season.isEmpty || !d.lastEpisode.isEmpty {
                        let parts = [d.season, d.lastEpisode].filter { !$0.isEmpty }
                        Text(parts.joined(separator: " / "))
                            .font(.footnote).bold()
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.25))
                            .clipShape(Capsule())
                    }

                    if vm.selectedPlayer != nil {
                        Button {
                            showPlayer = true
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Смотреть")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }

                    if let d = vm.detail, !d.voices.isEmpty {
                        infoRow(title: "Озвучки", value: d.voices)
                    }

                    if let d = vm.detail, d.players.count > 1 {
                        SectionTitle("Плееры")
                        voicePicker(d.players)
                    }

                    if let d = vm.detail, !d.actors.isEmpty {
                        SectionTitle("В главных ролях")
                        actorsRow(d.actors)
                    }

                    if let d = vm.detail, !d.description.isEmpty {
                        SectionTitle("Описание")
                        Text(d.description)
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    if let d = vm.detail, !d.related.isEmpty {
                        SectionTitle("Рекомендации к просмотру")
                        relatedRow(d.related)
                    }

                    if let err = vm.errorText {
                        Text(err).font(.footnote).foregroundStyle(.orange)
                    }

                    Spacer(minLength: 40)
                }
                .padding(16)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            if let d = vm.detail, !d.poster.isEmpty {
                MoviePoster(url: d.poster, width: 130, height: 190)
            } else if !movie.poster.isEmpty {
                MoviePoster(url: movie.poster, width: 130, height: 190)
            } else {
                Color.gray.opacity(0.2).frame(width: 130, height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(vm.detail?.title.isEmpty == false ? vm.detail!.title : movie.title)
                    .font(.title3).bold().foregroundStyle(.white)
                    .lineLimit(3)
                if let d = vm.detail, !d.genres.isEmpty {
                    Text(d.genres)
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var metaLine: some View {
        if let d = vm.detail {
            let parts = [d.year, d.country, d.duration, d.quality].filter { !$0.isEmpty }
            if !parts.isEmpty {
                Text(parts.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.gray)
            Text(value)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(3)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func voicePicker(_ players: [Player]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(players) { p in
                    Button {
                        vm.selectedPlayer = p
                    } label: {
                        Text(p.name)
                            .font(.caption)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(vm.selectedPlayer?.id == p.id ? Color.blue : Color.white.opacity(0.1))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func actorsRow(_ actors: [Actor]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(actors) { a in
                    if a.url.isEmpty {
                        actorCard(a)
                    } else {
                        NavigationLink {
                            ActorView(actor: a)
                        } label: {
                            actorCard(a)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func actorCard(_ a: Actor) -> some View {
        VStack(spacing: 6) {
            ActorAvatar(actor: a, size: 80)
            Text(a.name)
                .font(.caption2)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 80)
        }
    }

    private func relatedRow(_ movies: [Movie]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(movies) { m in
                    NavigationLink {
                        MovieDetailView(movie: m)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            if m.poster.isEmpty {
                                ZStack {
                                    Color.gray.opacity(0.2)
                                    Image(systemName: "film")
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .frame(width: 110, height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                MoviePoster(url: m.poster, width: 110, height: 160, cornerRadius: 8)
                            }
                            Text(m.title)
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                                .frame(width: 110, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ActorAvatar: View {
    let actor: Actor
    let size: CGFloat

    var body: some View {
        Group {
            if actor.photo.isEmpty {
                ZStack {
                    Circle().fill(Color.blue.opacity(0.5))
                    Text(String(actor.name.prefix(1)).uppercased())
                        .font(.system(size: size * 0.4)).bold()
                        .foregroundStyle(.white)
                }
                .frame(width: size, height: size)
            } else {
                MoviePoster(url: actor.photo, width: size, height: size, cornerRadius: size / 2)
            }
        }
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.subheadline).bold()
            .foregroundStyle(.white.opacity(0.7))
            .padding(.top, 6)
    }
}
