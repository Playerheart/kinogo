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
            let json = try await SiteParser.shared.extract(from: url, js: ExtractionScripts.detail, waitAfterLoad: 4.0)
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

                    // Постер + название
                    header

                    // Кнопка "Смотреть"
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

                    // Озвучка
                    if let d = vm.detail, d.players.count > 1 {
                        SectionTitle("Озвучка")
                        voicePicker(d.players)
                    }

                    // Актёры
                    if let d = vm.detail, !d.actors.isEmpty {
                        SectionTitle("В главных ролях")
                        actorsRow(d.actors)
                    }

                    // Описание
                    if let d = vm.detail, !d.description.isEmpty {
                        SectionTitle("Описание")
                        Text(d.description)
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.9))
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
                if !movie.year.isEmpty {
                    Text(movie.year).font(.subheadline).foregroundStyle(.gray)
                }
            }
            Spacer()
        }
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
                    VStack(spacing: 6) {
                        MoviePoster(url: a.photo, width: 80, height: 80, cornerRadius: 40)
                        Text(a.name)
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(width: 80)
                    }
                }
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
