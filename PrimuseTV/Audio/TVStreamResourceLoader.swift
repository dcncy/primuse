#if os(tvOS)
import AVFoundation
import Foundation
import UniformTypeIdentifiers

/// 让 AVPlayer 播放"需要自定义 HTTP 头(UA / Bearer)"的流(百度网盘 / 115 / Google Drive)。
///
/// 做法:把真实 https URL 换成自定义 scheme,AVPlayer 便把加载请求交给本 delegate;
/// 我们带上自定义头、按 AVPlayer 请求的字节范围去真实 URL 拉数据再回填,支持 Range 与 seek。
final class TVStreamResourceLoader: NSObject, AVAssetResourceLoaderDelegate, URLSessionDataDelegate, @unchecked Sendable {
    static let scheme = "primusehdr"

    private let realURL: URL
    private let headers: [String: String]
    private let explicitContentType: String?   // 已知文件格式推得的 UTType id(覆盖服务器误报的 octet-stream)
    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.timeoutIntervalForRequest = 60
        cfg.timeoutIntervalForResource = 600
        return URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }()
    private let lock = NSLock()
    private var tasks: [ObjectIdentifier: URLSessionDataTask] = [:]
    private var taskToRequestID: [Int: ObjectIdentifier] = [:]
    private var contexts: [Int: LoadingContext] = [:]

    private final class LoadingContext: @unchecked Sendable {
        let loadingRequest: AVAssetResourceLoadingRequest
        let offset: Int64
        let length: Int64
        let isInfoRequest: Bool
        var byteCount: Int = 0
        var loggedFirstData: Bool = false

        init(loadingRequest: AVAssetResourceLoadingRequest,
             offset: Int64,
             length: Int64,
             isInfoRequest: Bool) {
            self.loadingRequest = loadingRequest
            self.offset = offset
            self.length = length
            self.isInfoRequest = isInfoRequest
        }
    }

    init(realURL: URL, headers: [String: String], fileExtension: String? = nil) {
        self.realURL = realURL
        self.headers = headers
        self.explicitContentType = fileExtension.flatMap { UTType(filenameExtension: $0)?.identifier }
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
        let length: Int64
        if let dataReq = loadingRequest.dataRequest {
            let requestedStart = max(0, dataReq.requestedOffset)
            let current = dataReq.currentOffset > 0 ? dataReq.currentOffset : requestedStart
            let requestedEnd = requestedStart + Int64(max(1, dataReq.requestedLength))
            offset = max(0, current)
            length = max(1, requestedEnd - offset)
        } else {
            offset = 0
            length = 2   // 仅取内容信息时拉头两字节即可拿到 Content-Range/Type
        }
        req.setValue("bytes=\(offset)-\(offset + length - 1)", forHTTPHeaderField: "Range")

        let id = ObjectIdentifier(loadingRequest)
        let isInfoReq = loadingRequest.contentInformationRequest != nil
        let task = session.dataTask(with: req)
        let context = LoadingContext(
            loadingRequest: loadingRequest,
            offset: offset,
            length: length,
            isInfoRequest: isInfoReq
        )
        lock.lock()
        tasks[id] = task
        taskToRequestID[task.taskIdentifier] = id
        contexts[task.taskIdentifier] = context
        lock.unlock()
        task.resume()
        return true
    }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                        didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        let id = ObjectIdentifier(loadingRequest)
        lock.lock()
        let task = tasks[id]
        tasks[id] = nil
        if let task {
            taskToRequestID[task.taskIdentifier] = nil
            contexts[task.taskIdentifier] = nil
        }
        lock.unlock()
        task?.cancel()
    }

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse else {
            completionHandler(.allow)
            return
        }
        lock.lock()
        let context = contexts[dataTask.taskIdentifier]
        lock.unlock()
        guard let context else {
            completionHandler(.cancel)
            return
        }

        if let info = context.loadingRequest.contentInformationRequest {
            Self.fillContentInfo(info, from: http, explicit: explicitContentType)
            plog("📺 loader info status=\(http.statusCode) ct=\(info.contentType ?? "nil") len=\(info.contentLength) ranges=\(info.isByteRangeAccessSupported) serverCT=\(http.value(forHTTPHeaderField: "Content-Type") ?? "nil")")
        }

        switch http.statusCode {
        case 200, 206:
            completionHandler(.allow)
        default:
            let error = NSError(
                domain: "TVStreamResourceLoader",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]
            )
            context.loadingRequest.finishLoading(with: error)
            completionHandler(.cancel)
        }
    }

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        lock.lock()
        let context = contexts[dataTask.taskIdentifier]
        lock.unlock()
        guard let context else { return }

        context.byteCount += data.count
        if let dataRequest = context.loadingRequest.dataRequest {
            dataRequest.respond(with: data)
            if !context.loggedFirstData {
                context.loggedFirstData = true
                plog("📺 loader data first off=\(context.offset) len=\(context.length) got=\(data.count)")
            }
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        lock.lock()
        let context = contexts[task.taskIdentifier]
        let requestID = taskToRequestID[task.taskIdentifier]
        contexts[task.taskIdentifier] = nil
        taskToRequestID[task.taskIdentifier] = nil
        if let requestID {
            tasks[requestID] = nil
        }
        lock.unlock()

        guard let context else { return }
        if let error {
            if (error as NSError).code != NSURLErrorCancelled {
                plog("📺 loader \(context.isInfoRequest ? "info" : "data") off=\(context.offset) ERROR — \(error.localizedDescription)")
                context.loadingRequest.finishLoading(with: error)
            }
            return
        }
        if !context.isInfoRequest {
            plog("📺 loader data done off=\(context.offset) bytes=\(context.byteCount)")
        }
        context.loadingRequest.finishLoading()
    }

    /// 接受自签 / 不受信任的服务器证书(个人 NAS 常见)。AVPlayer 无 app 层 TLS 钩子,
    /// 所以把流走这条带此 delegate 的 URLSession 代理,才能播放自签证书的 NAS。
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    static func fillContentInfo(_ info: AVAssetResourceLoadingContentInformationRequest,
                                from http: HTTPURLResponse, explicit: String? = nil) {
        // 优先用「已知文件格式」推得的 UTType:个人 NAS / 云盘下载端常返回
        // application/octet-stream,UTType(mimeType:) 解析不出可播类型 → AVPlayer
        // 直接「Cannot Open」。显式给定 FLAC/MP3 等类型才能播。
        if let explicit {
            info.contentType = explicit
        } else if let raw = http.value(forHTTPHeaderField: "Content-Type")?
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

/// 接受自签 / 不受信任的服务器证书(个人 NAS 常见)。用于歌词等非播放请求。
final class TVInsecureTLSDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

#endif
