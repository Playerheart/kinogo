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
        var player: AVPlayer?

        func start(url: URL) {
            // Копируем cookies из WKWebView в общий HTTPCookieStorage,
            // чтобы AVPlayer мог их подхватить автоматически.
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self = self else { return }
                for c in cookies {
                    HTTPCookieStorage.shared.setCookie(c)
                }

                DispatchQueue.main.async {
                    let asset = AVURLAsset(url: url)
                    let item = AVPlayerItem(asset: asset)
                    let player = AVPlayer(playerItem: item)
                    self.player = player
                    self.vc?.player = player
                    player.play()
                }
            }
        }
    }
}
