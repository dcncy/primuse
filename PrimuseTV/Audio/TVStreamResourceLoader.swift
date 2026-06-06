#if os(tvOS)
import AVFoundation
import Foundation
import UniformTypeIdentifiers

/// 让 AVPlayer 播放"需要自定义 HTTP 头(UA / Bearer)"的流(百度网盘 / 115 / Google Drive)。
///
/// 做法:把真实 https URL 换成自定义 scheme,AVPlayer 便把加载请求交给本 delegate;
/// 我们带上自定义头、按 AVPlayer 请求的字节范围去真实 URL 拉数据再回填,支持 Range 与 seek。
final class TVStreamResourceLoader: NSObject, AVAssetResourceLoaderDelegate, @unchecked Sendable {
    static let scheme = "primusehdr"

    private let realURL: URL
    private let headers: [String: String]
    private let session: URLSession
    private let lock = NSLock()
    private var tasks: [ObjectIdentifier: URLSessionDataTask] = [:]

    init(realURL: URL, headers: [String: String]) {
        self.realURL = realURL
        self.headers = headers
        let cfg = URLSessionConfiguration.default
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: cfg)
        super.init()
    }

    /// 把真实 URL 换成自定义 scheme 给 AVURLAsset 用。
    static func maskedURL(from real: URL) -> URL? {
        guard var comp = URLComponents(url: real, resolvingAgainstBaseURL: false) else { return nil }
        comp.scheme = scheme
        return comp.url
    }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        var req = URLRequest(url: realURL)
        for (key, value) in headers { req.setValue(value, forHTTPHeaderField: key) }

        let offset: Int64
        let length: Int
        if let dataReq = loadingRequest.dataRequest {
            offset = dataReq.requestedOffset
            length = dataReq.requestedLength
        } else {
            offset = 0
            length = 2   // 仅取内容信息时拉头两字节即可拿到 Content-Range/Type
        }
        req.setValue("bytes=\(offset)-\(offset + Int64(max(1, length)) - 1)", forHTTPHeaderField: "Range")

        let id = ObjectIdentifier(loadingRequest)
        let task = session.dataTask(with: req) { [weak self] data, response, error in
            self?.lock.lock(); self?.tasks[id] = nil; self?.lock.unlock()
            if let error {
                if (error as NSError).code != NSURLErrorCancelled { loadingRequest.finishLoading(with: error) }
                return
            }
            if let info = loadingRequest.contentInformationRequest, let http = response as? HTTPURLResponse {
                Self.fillContentInfo(info, from: http)
            }
            if let dataReq = loadingRequest.dataRequest, let data {
                dataReq.respond(with: data)
            }
            loadingRequest.finishLoading()
        }
        lock.lock(); tasks[id] = task; lock.unlock()
        task.resume()
        return true
    }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                        didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        let id = ObjectIdentifier(loadingRequest)
        lock.lock(); let task = tasks[id]; tasks[id] = nil; lock.unlock()
        task?.cancel()
    }

    static func fillContentInfo(_ info: AVAssetResourceLoadingContentInformationRequest, from http: HTTPURLResponse) {
        if let raw = http.value(forHTTPHeaderField: "Content-Type")?
            .split(separator: ";").first.map({ $0.trimmingCharacters(in: .whitespaces) }),
           let uti = UTType(mimeType: raw) {
            info.contentType = uti.identifier
        }
        info.isByteRangeAccessSupported = http.statusCode == 206
            || http.value(forHTTPHeaderField: "Accept-Ranges")?.contains("bytes") == true
        // 优先用 Content-Range 的总长度(bytes a-b/total)
        if let range = http.value(forHTTPHeaderField: "Content-Range"),
           let totalStr = range.split(separator: "/").last, let total = Int64(totalStr) {
            info.contentLength = total
        } else if http.statusCode == 200,
                  let lenStr = http.value(forHTTPHeaderField: "Content-Length"), let len = Int64(lenStr) {
            info.contentLength = len
        }
    }
}
#endif
