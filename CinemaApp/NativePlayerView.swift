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
        context.coordinator.vc = vc
        context.coordinator.start(url: url)
        return vc
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        weak var vc: AVPlayerViewController?
        var loader: HeaderResourceLoader?

        func start(url: URL) {
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                var headers = HLSPrepare.baseHeaders
                let pairs = cookies
                    .filter { $0.domain.contains("cinemar") || $0.domain.contains("cinemap") || $0.domain.contains("kinogo") }
                    .map { "\($0.name)=\($0.value)" }
                if !pairs.isEmpty { headers["Cookie"] = pairs.joined(separator: "; ") }

                HLSPrepare.prepare(url: url, headers: headers) { [weak self] prepared in
                    guard let self = self else { return }
                    DispatchQueue.main.async { self.play(prepared) }
                }
            }
        }

        private func play(_ prepared: HLSPrepare.Result) {
            let asset = AVURLAsset(url: prepared.playbackURL)
            if let loader = prepared.loader {
                asset.resourceLoader.setDelegate(loader, queue: DispatchQueue.global(qos: .userInitiated))
                self.loader = loader
            }
            let item = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: item)
            vc?.player = player
            player.play()
        }
    }
}
