import SwiftUI
import AVKit
import AVFoundation

struct NativePlayerView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let headers: [String: String] = [
            "Referer": "https://cinemar.cc/",
            "Origin": "https://cinemar.cc",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        ]

        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let origScheme = (comps?.scheme ?? "https").lowercased()
        comps?.scheme = (origScheme == "https") ? "cinemap-https" : "cinemap-http"
        let proxyURL = comps?.url ?? url

        let asset = AVURLAsset(url: proxyURL)
        let loader = HeaderResourceLoader(headers: headers, originalScheme: origScheme)
        asset.resourceLoader.setDelegate(loader, queue: DispatchQueue.global(qos: .userInitiated))
        context.coordinator.loader = loader

        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = true
        vc.allowsPictureInPicturePlayback = true
        player.play()
        return vc
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var loader: HeaderResourceLoader?
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

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard let customURL = loadingRequest.request.url else { return false }

        var comps = URLComponents(url: customURL, resolvingAgainstBaseURL: false)
        comps?.scheme = originalScheme
        guard let realURL = comps?.url else { return false }

        var req = URLRequest(url: realURL)
        for (k, v) in headers {
            req.setValue(v, forHTTPHeaderField: k)
        }
        if let range = loadingRequest.dataRequest?.requestedOffset, range > 0 {
            let length = loadingRequest.dataRequest?.requestedLength ?? 0
            req.setValue("bytes=\(range)-\(range + Int64(max(length, 0)) - 1)", forHTTPHeaderField: "Range")
        }

        let task = URLSession.shared.dataTask(with: req) { data, response, error in
            if let error = error {
                loadingRequest.finishLoading(with: error)
                return
            }
            guard var data = data, let http = response as? HTTPURLResponse else {
                loadingRequest.finishLoading(with: NSError(domain: "HeaderResourceLoader", code: -1))
                return
            }

            if let info = loadingRequest.contentInformationRequest {
                info.contentType = http.mimeType ?? "application/octet-stream"
                info.contentLength = Int64(data.count)
                info.isByteRangeAccessSupported = false
            }

            // Если это m3u8-плейлист — переписываем абсолютные ссылки на сегменты в кастомную схему,
            // чтобы они тоже шли через этот загрузчик (иначе AVPlayer пойдёт напрямую без Referer).
            if let str = String(data: data, encoding: .utf8), str.contains("#EXTM3U") {
                let rewritten = HeaderResourceLoader.rewritePlaylist(str)
                if let d = rewritten.data(using: .utf8) { data = d }
            }

            loadingRequest.dataRequest?.respond(with: data)
            loadingRequest.finishLoading()
        }
        task.resume()
        return true
    }

    private static func rewritePlaylist(_ s: String) -> String {
        var lines = s.components(separatedBy: "\n")
        for i in 0..<lines.count {
            var l = lines[i]
            // Прямые URL на сегменты
            if l.hasPrefix("https://") { l = "cinemap-" + l }
            else if l.hasPrefix("http://") { l = "cinemap-" + l }
            // URI в EXT-X-KEY / EXT-X-MAP / EXT-X-MEDIA
            l = l.replacingOccurrences(of: "URI=\"https://", with: "URI=\"cinemap-https://")
            l = l.replacingOccurrences(of: "URI=\"http://",  with: "URI=\"cinemap-http://")
            lines[i] = l
        }
        return lines.joined(separator: "\n")
    }
}
