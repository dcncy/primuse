import Foundation
import Testing
@testable import PrimuseKit

// MARK: - S3 SigV4 预签名(对齐 AWS 官方文档向量)
// AWS「Authenticating Requests: Using Query Parameters」GET examplebucket/test.txt 示例,
// 期望签名为 aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404。

@Test func s3PresignMatchesAWSVector() {
    let url = S3StreamResolver.presignedURL(
        method: "GET", scheme: "https", host: "examplebucket.s3.amazonaws.com",
        canonicalURI: "/test.txt",
        accessKey: "AKIAIOSFODNN7EXAMPLE",
        secretKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
        region: "us-east-1", service: "s3",
        amzDate: "20130524T000000Z", dateStamp: "20130524", expires: 86400)
    let s = url?.absoluteString ?? ""
    #expect(s.contains("X-Amz-Signature=aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404"))
    #expect(s.contains("X-Amz-Credential=AKIAIOSFODNN7EXAMPLE%2F20130524%2Fus-east-1%2Fs3%2Faws4_request"))
    #expect(s.hasPrefix("https://examplebucket.s3.amazonaws.com/test.txt?"))
}

@Test func s3URIEncode() {
    #expect(S3StreamResolver.uriEncode("a/b c", encodeSlash: false) == "a/b%20c")
    #expect(S3StreamResolver.uriEncode("a/b c", encodeSlash: true) == "a%2Fb%20c")
    #expect(S3StreamResolver.uriEncode("AZaz09-._~", encodeSlash: false) == "AZaz09-._~")
}

@Test func s3RegionParsing() {
    #expect(S3StreamResolver.region(from: #"{"region":"eu-west-1"}"#) == "eu-west-1")
    #expect(S3StreamResolver.region(from: nil) == "us-east-1")
    #expect(S3StreamResolver.region(from: "{}") == "us-east-1")
    #expect(S3StreamResolver.host(from: "https://minio.example.com:9000/x") == "minio.example.com:9000")
}

@Test func s3EndToEnd() async throws {
    let song = Song(id: "s", title: "T", fileFormat: .flac,
                    filePath: "artists/song.flac", sourceID: "src")
    let source = MusicSource(name: "S3", type: .s3, host: "s3.amazonaws.com",
                             useSsl: true, username: "AKIA", basePath: "my-bucket",
                             extraConfig: #"{"region":"us-west-2"}"#)
    let url = try await S3StreamResolver().streamURL(for: song, source: source,
                                                     credential: SourceCredential(password: "secret"))
    let s = url.absoluteString
    #expect(s.hasPrefix("https://s3.amazonaws.com/my-bucket/artists/song.flac?"))
    #expect(s.contains("X-Amz-Algorithm=AWS4-HMAC-SHA256"))
    #expect(s.contains("X-Amz-Signature="))
    #expect(s.contains("us-west-2%2Fs3%2Faws4_request"))
}

// MARK: - Synology FileStation URL 构造

@Test func synologyBaseURL() {
    #expect(SynologyStreamResolver.baseURL(host: "nas.local", port: 5001, useSsl: true)?.absoluteString
            == "https://nas.local:5001")
    #expect(SynologyStreamResolver.baseURL(host: "http://192.168.1.9", port: 5000, useSsl: false)?.absoluteString
            == "http://192.168.1.9:5000")
}

@Test func synologyDownloadURL() {
    let base = URL(string: "https://nas.local:5001")!
    let url = SynologyStreamResolver.downloadURL(base: base, path: "/music/a.flac", sid: "SID123")
    let q = Dictionary(uniqueKeysWithValues:
        (URLComponents(url: url!, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    #expect(url?.path == "/webapi/entry.cgi")
    #expect(q["api"] == "SYNO.FileStation.Download")
    #expect(q["method"] == "download")
    #expect(q["path"] == "/music/a.flac")
    #expect(q["_sid"] == "SID123")
}

// MARK: - 注册表覆盖

@Test func registryCoversNasAndS3() async {
    let supported = await StreamResolverRegistry().supportedTypes
    #expect(supported.isSuperset(of: [.subsonic, .navidrome, .airsonic, .gonic, .synology, .s3]))
    #expect(!supported.contains(.smb))      // 原生库源仍不支持
    #expect(!supported.contains(.appleMusic))
}
