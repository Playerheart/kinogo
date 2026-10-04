import SwiftUI

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private init() { cache.countLimit = 200 }
    func get(_ key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func set(_ key: String, _ image: UIImage) { cache.setObject(image, forKey: key as NSString) }
}

struct MoviePoster: View {
    let url: String
    var width: CGFloat
    var height: CGFloat
    var cornerRadius: CGFloat = 10

    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.gray.opacity(0.2)
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                ProgressView().tint(.white.opacity(0.6))
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: url) { await load() }
    }

    private func load() async {
        guard image == nil, !isLoading else { return }
        if let cached = ImageCache.shared.get(url) {
            await MainActor.run { self.image = cached }
            return
        }
        guard let u = URL(string: url) else { return }
        await MainActor.run { self.isLoading = true }

        var request = URLRequest(url: u)
        request.setValue("https://mix.kinogo.mu/", forHTTPHeaderField: "Referer")
        request.setValue("https://mix.kinogo.mu/", forHTTPHeaderField: "Origin")
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 20

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                await MainActor.run { self.isLoading = false }
                return
            }
            if let img = UIImage(data: data) {
                ImageCache.shared.set(url, img)
                await MainActor.run { self.image = img; self.isLoading = false }
                return
            }
        } catch {}
        await MainActor.run { self.isLoading = false }
    }
}
