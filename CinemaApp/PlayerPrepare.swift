import Foundation
import AVFoundation
import WebKit

enum HLSPrepare {
    static let baseHeaders: [String: String] = [
        "Referer": "https://cinemar.cc/",
        "Origin": "https://cinemar.cc",
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    ]
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

        var request = URLRequest(url: realURL,
                                 cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: 15)
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
            if urlString.contains(".m3u8") || urlString.contains("manifest") || urlString.contains("hls") {
                mime = "application/vnd.apple.mpegurl"
            } else if urlString.contains(".ts") {
                mime = "video/mp2t"
            } else if urlString.contains(".mp4") {
                mime = "video/mp4"
            }

            // Если это HLS-плейлист — переписываем все относительные ссылки
            // в абсолютные + добавляем cinemap-https:// для дальнейшей обработки
            if let str = String(data: data, encoding: .utf8), str.contains("#EXTM3U") {
                let rewritten = Self.rewritePlaylist(str, baseURL: realURL)
                if let d = rewritten.data(using: .utf8) { data = d }
                mime = "application/vnd.apple.mpegurl"
            }

            if let info = req.contentInformationRequest {
                info.contentType = mime
                info.contentLength = Int64(data.count)
                info.isByteRangeAccessSupported = false
            }

            req.dataRequest?.respond(with: data)
            req.finishLoading()
        }
        task.resume()
        return true
    }

    private static func rewritePlaylist(_ s: String, baseURL: URL) -> String {
        var lines = s.components(separatedBy: "\n")
        for i in 0..<lines.count {
            let original = lines[i]
            if original.isEmpty { continue }
            var l = original

            // Директивы с URI="..."
            if l.hasPrefix("#") {
                l = l.replacingOccurrences(of: "URI=\"https://", with: "URI=\"cinemap-https://")
                l = l.replacingOccurrences(of: "URI=\"http://",  with: "URI=\"cinemap-http://")
                // Относительные URI="..."
                if l.contains("URI=\"") && !l.contains("URI=\"cinemap-") && !l.contains("URI=\"data:") {
                    if let r = l.range(of: "URI=\"") {
                        let after = l[r.upperBound...]
                        if let close = after.firstIndex(of: "\"") {
                            let inner = String(after[..<close])
                            if !inner.hasPrefix("http") && !inner.hasPrefix("cinemap-") {
                                if let abs = URL(string: inner, relativeTo: baseURL)?.absoluteURL {
                                    let replaced = l.replacingOccurrences(
                                        of: "URI=\"\(inner)\"",
                                        with: "URI=\"cinemap-\(abs.absoluteString)\""
                                    )
                                    l = replaced
                                }
                            }
                        }
                    }
                }
                lines[i] = l
                continue
            }

            // Уже переписан
            if l.hasPrefix("cinemap-") {
                lines[i] = l
                continue
            }

            // Абсолютный URL
            if l.hasPrefix("https://") {
                lines[i] = "cinemap-" + l
                continue
            }
            if l.hasPrefix("http://") {
                lines[i] = "cinemap-" + l
                continue
            }

            // Относительный путь — резолвим через baseURL
            if let abs = URL(string: original, relativeTo: baseURL)?.absoluteURL {
                lines[i] = "cinemap-" + abs.absoluteString
            }
        }
        return lines.joined(separator: "\n")
    }
}

enum Downloader {
    enum DL: Error { case http(Int), emptyPlaylist, parseFailed }

    static func downloadHLS(url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            var headers = HLSPrepare.baseHeaders
            let pairs = cookies
                .filter { $0.domain.contains("cinemar") || $0.domain.contains("cinemap") || $0.domain.contains("kinogo") }
                .map { "\($0.name)=\($0.value)" }
            if !pairs.isEmpty { headers["Cookie"] = pairs.joined(separator: "; ") }

            fetchText(url: url, headers: headers) { master in
                switch master {
                case .failure(let e):
                    completion(.failure(e))
                case .success(let text):
                    guard text.contains("#EXTM3U") else {
                        fetchBinary(url: url, headers: headers, completion: completion)
                        return
                    }
                    let variantURL = parseFirstVariant(text, base: url) ?? url
                    fetchText(url: variantURL, headers: headers) { variantRes in
                        switch variantRes {
                        case .failure(let e): completion(.failure(e))
                        case .success(let vtext):
                            let segments = parseSegments(vtext, base: variantURL)
                            guard !segments.isEmpty else {
                                completion(.failure(DL.emptyPlaylist))
                                return
                            }
                            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                            let dest = docs.appendingPathComponent("video.ts")
                            try? FileManager.default.removeItem(at: dest)
                            FileManager.default.createFile(atPath: dest.path, contents: nil)
                            guard let handle = try? FileHandle(forWritingTo: dest) else {
                                completion(.failure(DL.parseFailed))
                                return
                            }
                            let group = DispatchGroup()
                            var hadError: Error?
                            let lock = NSLock()
                            for seg in segments {
                                group.enter()
                                fetchBinary(url: seg, headers: headers) { res in
                                    lock.lock()
                                    if case .success(let fileURL) = res,
                                       let data = try? Data(contentsOf: fileURL) {
                                        handle.write(data)
                                    } else if case .failure(let e) = res, hadError == nil {
                                        hadError = e
                                    }
                                    lock.unlock()
                                    group.leave()
                                }
                            }
                            group.notify(queue: .global()) {
                                try? handle.close()
                                if let e = hadError { completion(.failure(e)); return }
                                completion(.success(dest))
                            }
                        }
                    }
                }
            }
        }
    }

    private static func fetchText(url: URL, headers: [String: String], completion: @escaping (Result<String, Error>) -> Void) {
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        URLSession.shared.dataTask(with: req) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(DL.parseFailed)); return
            }
            guard (200...299).contains(http.statusCode) else {
                completion(.failure(DL.http(http.statusCode))); return
            }
            let text = String(data: data ?? Data(), encoding: .utf8) ?? ""
            completion(.success(text))
        }.resume()
    }

    private static func fetchBinary(url: URL, headers: [String: String], completion: @escaping (Result<URL, Error>) -> Void) {
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        URLSession.shared.downloadTask(with: req) { local, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(DL.parseFailed)); return
            }
            guard (200...299).contains(http.statusCode) else {
                completion(.failure(DL.http(http.statusCode))); return
            }
            guard let local = local else { completion(.failure(DL.parseFailed)); return }
            completion(.success(local))
        }.resume()
    }

    private static func parseFirstVariant(_ master: String, base: URL) -> URL? {
        for l in master.components(separatedBy: "\n") {
            let t = l.trimmingCharacters(in: .whitespaces)
            if t.isEmpty || t.hasPrefix("#") { continue }
            if let u = URL(string: t, relativeTo: base)?.absoluteURL { return u }
        }
        return nil
    }

    private static func parseSegments(_ playlist: String, base: URL) -> [URL] {
        var out: [URL] = []
        for l in playlist.components(separatedBy: "\n") {
            let t = l.trimmingCharacters(in: .whitespaces)
            if t.isEmpty || t.hasPrefix("#") { continue }
            if let u = URL(string: t, relativeTo: base)?.absoluteURL { out.append(u) }
        }
        return out
    }
}
