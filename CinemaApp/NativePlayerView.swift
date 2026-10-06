import SwiftUI
import AVKit
import AVFoundation
import WebKit

struct NativePlayerView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.showsPlaybackControls = true
        vc.allowsPictureInPicturePlayback = true
        context.coordinator.start(url: url, into: vc)
        return vc
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var loader: HeaderResourceLoader?
        var player: AVPlayer?
        var vc: AVPlayerViewController?

        func start(url: URL, into vc: AVPlayerViewController) {
            self.vc = vc

            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self = self else { return }
                var headers = HLSPrepare.baseHeaders
                let pairs = cookies
                    .filter { $0.domain.contains("cinemar") || $0.domain.contains("cinemap") || $0.domain.contains("kinogo") }
                    .map { "\($0.name)=\($0.value)" }
                if !pairs.isEmpty { headers["Cookie"] = pairs.joined(separator: "; ") }

                // Обёртка: схема становится cinemap-https, чтобы AVPlayer прогнал
                // весь трафик HLS через наш loader.
                var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
                let orig = (comps?.scheme ?? "https").lowercased()
                comps?.scheme = (orig == "https") ? "cinemap-https" : "cinemap-http"
                let proxy = comps?.url ?? url

                let asset = AVURLAsset(url: proxy)
                let loader = HeaderResourceLoader(headers: headers, originalScheme: orig)
                asset.resourceLoader.setDelegate(loader, queue: DispatchQueue.global(qos: .userInitiated))
                self.loader = loader

                DispatchQueue.main.async {
                    let item = AVPlayerItem(asset: asset)
                    let player = AVPlayer(playerItem: item)
                    self.player = player
                    vc.player = player
                    player.play()
                }
            }
        }
    }
}
