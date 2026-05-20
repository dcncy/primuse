import AVFoundation
import Foundation
import PrimuseKit

enum FileMetadataReader {
    struct Metadata {
        var title: String?
        var artist: String?
        var albumTitle: String?
        var albumArtist: String?
        var trackNumber: Int?
        var discNumber: Int?
        var year: Int?
        var genre: String?
        var duration: TimeInterval?
        var coverArtData: Data?
        var sampleRate: Int?
        var bitRate: Int?
        var bitDepth: Int?
        var replayGainTrackGain: Double?
        var replayGainTrackPeak: Double?
        var replayGainAlbumGain: Double?
        var replayGainAlbumPeak: Double?
        var lyricsText: String?
    }

    /// Reads metadata from an audio file using AVFoundation
    static func read(from url: URL) async -> Metadata {
        var metadata = Metadata()

        let asset = AVURLAsset(url: url)

        // Get duration
        if let duration = try? await asset.load(.duration) {
            let seconds = CMTimeGetSeconds(duration)
            if seconds.isFinite, seconds >= 0 {
                metadata.duration = seconds
            }
        }

        // Read metadata items
        if let items = try? await asset.load(.metadata) {
            for item in items {
                guard let key = item.commonKey?.rawValue else { continue }
                let value = try? await item.load(.value)

                switch key {
                case AVMetadataKey.commonKeyTitle.rawValue:
                    metadata.title = decodedText(value)
                case AVMetadataKey.commonKeyArtist.rawValue:
                    metadata.artist = decodedText(value)
                case AVMetadataKey.commonKeyAlbumName.rawValue:
                    metadata.albumTitle = decodedText(value)
                case AVMetadataKey.commonKeyArtwork.rawValue:
                    if let data = value as? Data {
                        metadata.coverArtData = data
                    }
                default:
                    break
                }
            }

            // Try format-specific metadata for more detail
            for item in items {
                guard let identifier = item.identifier else { continue }
                let value = try? await item.load(.value)

                switch identifier {
                case .id3MetadataTrackNumber, .iTunesMetadataTrackNumber:
                    if let str = decodedText(value) {
                        metadata.trackNumber = Int(str.split(separator: "/").first.map(String.init) ?? "")
                    } else if let num = value as? Int {
                        metadata.trackNumber = num
                    }
                case .id3MetadataPartOfASet:
                    if let str = decodedText(value) {
                        metadata.discNumber = Int(str.split(separator: "/").first.map(String.init) ?? "")
                    }
                case .id3MetadataYear, .id3MetadataRecordingTime:
                    if let str = decodedText(value) {
                        metadata.year = Int(String(str.prefix(4)))
                    }
                case .id3MetadataContentType:
                    metadata.genre = decodedText(value)
                case .id3MetadataUnsynchronizedLyric:
                    if let text = decodedText(value), !text.isEmpty {
                        metadata.lyricsText = text
                    }
                case .iTunesMetadataLyrics:
                    if let text = decodedText(value), !text.isEmpty, metadata.lyricsText == nil {
                        metadata.lyricsText = text
                    }
                case .id3MetadataUserText:
                    // TXXX frames: ReplayGain tags stored in extraAttributes[.info]
                    if let extras = try? await item.load(.extraAttributes),
                       let desc = extras[.info] as? String {
                        let stringValue = try? await item.load(.stringValue)
                        switch desc.lowercased() {
                        case "replaygain_track_gain":
                            metadata.replayGainTrackGain = parseReplayGainDB(stringValue)
                        case "replaygain_track_peak":
                            metadata.replayGainTrackPeak = Double(stringValue ?? "")
                        case "replaygain_album_gain":
                            metadata.replayGainAlbumGain = parseReplayGainDB(stringValue)
                        case "replaygain_album_peak":
                            metadata.replayGainAlbumPeak = Double(stringValue ?? "")
                        default:
                            break
                        }
                    }
                default:
                    break
                }
            }
        }

        // Get audio format details
        if let tracks = try? await asset.load(.tracks) {
            for track in tracks {
                if track.mediaType == .audio {
                    if let formatDescriptions = try? await track.load(.formatDescriptions) {
                        for desc in formatDescriptions {
                            let basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(desc)
                            if let basic = basicDescription?.pointee {
                                metadata.sampleRate = Int(basic.mSampleRate)
                                metadata.bitDepth = Int(basic.mBitsPerChannel)
                            }
                        }
                    }

                    if let bitRate = try? await track.load(.estimatedDataRate) {
                        metadata.bitRate = Int(bitRate / 1000) // kbps
                    }
                }
            }
        }

        // 注意: 不在这里用 url filename 兜底 title。
        // 调用方 (MetadataService) 自己决定 fallback 名 (走原始 NAS 文件名),
        // 这里要保持 metadata.title == nil 真实反映「文件里没有 TIT2」。
        // 否则 cache 内 sanitized 文件名 (如 "_music_xxx") 会被当成嵌入标题,
        // 污染 scrape 查询和 UI 预览。

        return metadata
    }

    /// Parse ReplayGain dB string like "-7.43 dB" or "+3.21 dB" to Double
    private static func parseReplayGainDB(_ value: String?) -> Double? {
        guard let value else { return nil }
        let cleaned = value
            .replacingOccurrences(of: " dB", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "dB", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }

    private static func decodedText(_ value: Any?) -> String? {
        if let text = value as? String {
            return repairLegacyChineseMojibake(text).nilIfEmpty
        }

        if let data = value as? Data {
            return decodeTextData(data)?.nilIfEmpty
        }

        return nil
    }

    private static func decodeTextData(_ data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        // ID3 text frames may carry a leading text encoding byte.
        let firstByte = data[data.startIndex]
        if [0, 1, 2, 3].contains(firstByte) {
            let payload = data.dropFirst()
            let decoded: String?

            switch firstByte {
            case 0:
                decoded = bestDecodedString(from: Data(payload), encodings: [gb18030Encoding, .isoLatin1, .windowsCP1252])
            case 1:
                decoded = bestDecodedString(from: Data(payload), encodings: [.utf16, .utf16LittleEndian, .utf16BigEndian])
            case 2:
                decoded = bestDecodedString(from: Data(payload), encodings: [.utf16BigEndian])
            case 3:
                decoded = bestDecodedString(from: Data(payload), encodings: [.utf8])
            default:
                decoded = nil
            }

            if let decoded {
                return repairLegacyChineseMojibake(decoded)
            }
        }

        return bestDecodedString(from: data, encodings: [.utf8, gb18030Encoding, .utf16, .isoLatin1, .windowsCP1252])
            .map(repairLegacyChineseMojibake)
    }

    static func repairLegacyChineseMojibake(_ text: String) -> String {
        let normalized = text.replacingOccurrences(of: "\0", with: "")
        guard looksLikeLegacyChineseMojibake(normalized) else { return normalized }

        let candidates = repairedTextCandidates(from: normalized)
        guard let best = candidates.max(by: { candidateScore($0, original: normalized) < candidateScore($1, original: normalized) }),
              shouldUseRepairedText(best, over: normalized) else {
            return normalized
        }

        return best
    }

    private static let gb18030Encoding = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        )
    )

    private static func bestDecodedString(from data: Data, encodings: [String.Encoding]) -> String? {
        let candidates = encodings.compactMap { String(data: data, encoding: $0) }
        guard !candidates.isEmpty else { return nil }

        return candidates.max { lhs, rhs in
            decodedStringScore(lhs) < decodedStringScore(rhs)
        }?.replacingOccurrences(of: "\0", with: "")
    }

    private static func repairedTextCandidates(from text: String) -> [String] {
        var candidates: [String] = []

        for sourceEncoding in [String.Encoding.isoLatin1, .windowsCP1252] {
            guard let bytes = text.data(using: sourceEncoding) else { continue }

            if let utf8 = String(data: bytes, encoding: .utf8) {
                candidates.append(utf8.replacingOccurrences(of: "\0", with: ""))
            }

            if let gb18030 = String(data: bytes, encoding: gb18030Encoding) {
                candidates.append(gb18030.replacingOccurrences(of: "\0", with: ""))
            }
        }

        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }
    }

    private static func looksLikeLegacyChineseMojibake(_ text: String) -> Bool {
        suspiciousMojibakeScalarCount(in: text) >= 2
    }

    private static func shouldUseRepairedText(_ candidate: String, over original: String) -> Bool {
        candidate != original
            && cjkScalarCount(in: candidate) > cjkScalarCount(in: original)
            && cjkScalarCount(in: candidate) > 0
            && suspiciousMojibakeScalarCount(in: candidate) < suspiciousMojibakeScalarCount(in: original)
            && replacementCharacterCount(in: candidate) == 0
    }

    private static func candidateScore(_ candidate: String, original: String) -> Int {
        decodedStringScore(candidate)
            + cjkScalarCount(in: candidate) * 8
            - abs(candidate.count - original.count)
    }

    private static func decodedStringScore(_ text: String) -> Int {
        cjkScalarCount(in: text) * 5
            - suspiciousMojibakeScalarCount(in: text) * 3
            - replacementCharacterCount(in: text) * 12
    }

    private static func cjkScalarCount(in text: String) -> Int {
        text.unicodeScalars.reduce(0) { count, scalar in
            let value = scalar.value
            return count + (isCJKScalar(value) ? 1 : 0)
        }
    }

    private static func suspiciousMojibakeScalarCount(in text: String) -> Int {
        text.unicodeScalars.reduce(0) { count, scalar in
            let value = scalar.value
            return count + ((0x00A1...0x00FF).contains(value) ? 1 : 0)
        }
    }

    private static func replacementCharacterCount(in text: String) -> Int {
        text.unicodeScalars.reduce(0) { count, scalar in
            count + (scalar.value == 0xFFFD ? 1 : 0)
        }
    }

    private static func isCJKScalar(_ value: UInt32) -> Bool {
        (0x3400...0x4DBF).contains(value)
            || (0x4E00...0x9FFF).contains(value)
            || (0xF900...0xFAFF).contains(value)
            || (0x20000...0x2A6DF).contains(value)
            || (0x2A700...0x2B73F).contains(value)
            || (0x2B740...0x2B81F).contains(value)
            || (0x2B820...0x2CEAF).contains(value)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
