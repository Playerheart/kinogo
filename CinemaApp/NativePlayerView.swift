import SwiftUI
import AVKit
import AVFoundation

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
            HLSPrepare.prepare(url: url) { [weak self] prepared in
                guard let self = self else { return }
                DispatchQueue.main.async { self.play(prepared) }
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

enum HLSPrepare {
    struct Result {
        let playbackURL: URL
        let loader: HeaderResourceLoader?
    }

    static let headers: [String: String] = [
        "Referer": "https://cinemar.cc/",
        "Origin": "https://cinemar.cc",
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    ]

    static func prepare(url: URL, completion: @escaping (Result) -> Void) {
        var req = URLRequest(url: url)
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data,
                  let str = String(data: data, encoding: .utf8),
                  str.contains("#EXTM3U") else {
                var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
                let orig = (comps?.scheme ?? "https").lowercased()
                comps?.scheme = (orig == "https") ? "cinemap-https" : "cinemap-http"
                let proxy = comps?.url ?? url
                let loader = HeaderResourceLoader(headers: headers, originalScheme: orig)
                completion(Result(playbackURL: proxy, loader: loader))
                return
            }

            let rewritten = rewritePlaylist(str, baseURL: url)
            let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            let local = dir.appendingPathComponent("playlist_\(UUID().uuidString).m3u8")
            try? rewritten.data(using: .utf8)?.write(to: local)

            let loader = HeaderResourceLoader(headers: headers, originalScheme: "https")
            completion(Result(playbackURL: local, loader: loader))
        }.resume()
    }

    static func rewritePlaylist(_ s: String, baseURL: URL) -> String {
        var lines = s.components(separatedBy: "\n")
        for i in 0..<lines.count {
            let original = lines[i]
            if original.isEmpty { continue }
            var l = original
            if l.hasPrefix("#") {
                l = l.replacingOccurrences(of: "URI=\"https://", with: "URI=\"cinemap-https://")
                l = l.replacingOccurrences(of: "URI=\"http://",  with: "URI=\"cinemap-http://")
            } else if l.hasPrefix("https://") {
                l = "cinemap-" + l
            } else if l.hasPrefix("http://") {
                l = "cinemap-" + l
            } else {
                if let abs = URL(string: original, relativeTo: baseURL)?.absoluteURL {
                    l = "cinemap-" + abs.absoluteString
                }
            }
            lines[i] = l
        }
        return lines.joined(separator: "\n")
    }
}

final class HeaderResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
    private let headers: [String: String]
    private let originalScheme: String

    init(headers: [String: String], originalScheme: String) {
        self.headers = headers
        self.originalScheme = originalScheme
        super.init()
    }

    func resourceLoader(_ rl: AVAssetResourceLoader,
                        shouldWaitForLoadingOfRequestedResource req: AVAssetResourceLoadingRequest) -> Bool {
        guard let customURL = req.request.url else { return false }
        var comps = URLComponents(url: customURL, resolvingAgainstBaseURL: false)
        comps?.scheme = originalScheme
        guard let realURL = comps?.url else { return false }

        var request = URLRequest(url: realURL)
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }

        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                req.finishLoading(with: error)
                return
            }
            guard var data = data else {
                req.finishLoading(with: NSError(domain: "HeaderResourceLoader", code: -1))
                return
            }

            let urlString = realURL.absoluteString.lowercased()
            var mime = "application/octet-stream"
            if urlString.contains(".m3u8") || urlString.contains("playlist") {
                mime = "application/vnd.apple.mpegurl"
            } else if urlString.contains(".ts") || urlString.contains(".mp4:hls") {
                mime = "video/mp2t"
            } else if urlString.contains(".mp4") {
                mime = "video/mp4"
            }

            if let info = req.contentInformationRequest {
                info.contentType = mime
                info.contentLength = Int64(data.count)
                info.isByteRangeAccessSupported = false
            }

            if let str = String(data: data, encoding: .utf8), str.contains("#EXTM3U") {
                let rewritten = Self.rewritePlaylist(str)
                if let d = rewritten.data(using: .utf8) { data = d }
                if let info = req.contentInformationRequest {
                    info.contentType = "application/vnd.apple.mpegurl"
                    info.contentLength = Int64(data.count)
                }
            }

            req.dataRequest?.respond(with: data)
            req.finishLoading()
        }
        task.resume()
        return true
    }

    private static func rewritePlaylist(_ s: String) -> String {
        var lines = s.components(separatedBy: "\n")
        for i in 0..<lines.count {
            let l = lines[i]
            var out = l
            if l.hasPrefix("#") {
                out = l.replacingOccurrences(of: "URI=\"https://", with: "URI=\"cinemap-https://")
                out = out.replacingOccurrences(of: "URI=\"http://",  with: "URI=\"cinemap-http://")
            } else if l.hasPrefix("https://") {
                out = "cinemap-" + l
            } else if l.hasPrefix("http://") {
                out = "cinemap-" + l
            }
            lines[i] = out
        }
        return lines.joined(separator: "\n")
    }
}
