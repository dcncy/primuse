import Accelerate
import AVFoundation
import Foundation

/// 实时音频频谱可视化器 —— 在 AudioEngine 的 mainMixerNode 上挂 tap, 拿到
/// 输出 buffer 做 FFT, 把 1024 点频谱压成 16 个频段强度发布给 UI。
///
/// 启停语义:
/// - `start(engine:)` 在 NowPlayingView onAppear 时调,绑定到当前的 AVAudioEngine
/// - `stop()` 在 NowPlayingView onDisappear / 后台 时调,卸 tap, 释放计算资源
/// - 主 player 暂停时 tap 会继续被调 (engine 仍在转),但读到的 buffer 是
///   静音,FFT 自然产出全 0,UI 自动归零,不需要特殊处理
///
/// 实现:
/// - FFT 走 vDSP.FFT (radix-2, log2n=10 → 1024 点),Hann window 减少 spectral leakage
/// - magnitudes -> log scale 转 dB -> 截 [-60dB, 0dB] -> 归一化到 0...1
/// - 16 频段做 log-spaced bin 累加,贴近人耳感知
/// - tap callback 在音频线程, 计算完后通过 main actor 派发到 `bandLevels`
@MainActor
@Observable
final class AudioVisualizerService {
    static let bandCount = 16

    /// 0...1 归一化的频段强度。bandLevels.count == bandCount 永远成立。
    /// UI 用 .animation(.linear(duration: 0.07), value: bandLevels) 即可平滑过渡。
    private(set) var bandLevels: [Float] = Array(repeating: 0, count: bandCount)

    private weak var engine: AVAudioEngine?
    private var tappedNode: AVAudioMixerNode?
    private let analyzer = FFTAnalyzer(log2n: 10)
    /// 上次发布时间, 25Hz 上限节流, 避免 main actor 被刷屏
    private var lastPublish: Date = .distantPast

    func start(engine: AVAudioEngine, on node: AVAudioMixerNode) {
        guard self.tappedNode == nil else { return }
        self.engine = engine
        self.tappedNode = node
        let format = node.outputFormat(forBus: 0)
        // bufferSize 1024 跟 FFT size 对齐, hop 一次性吃满, 不需要拼包
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            // 把 channel 0 的 float 样本拷出来 (channelData 是 UnsafePointer,
            // 离开 tap 闭包就失效, 必须立即复制)
            guard let chData = buffer.floatChannelData else { return }
            let count = Int(buffer.frameLength)
            guard count > 0 else { return }
            let samples = Array(UnsafeBufferPointer(start: chData[0], count: count))
            let levels = self.analyzer.bandLevels(samples: samples, bandCount: Self.bandCount)
            Task { @MainActor [weak self] in
                guard let self else { return }
                let now = Date()
                if now.timeIntervalSince(self.lastPublish) < 0.04 { return } // ≤ 25Hz
                self.lastPublish = now
                self.bandLevels = levels
            }
        }
    }

    func stop() {
        if let node = tappedNode {
            node.removeTap(onBus: 0)
        }
        tappedNode = nil
        engine = nil
        bandLevels = Array(repeating: 0, count: Self.bandCount)
    }
}

// MARK: - FFT analyzer

/// 把单声道 Float PCM 样本压成 logspaced 频段强度。完全跑在调用方的线程上
/// (tap callback = 音频线程), 不能 hop main actor 否则会卡音频渲染。
private final class FFTAnalyzer: @unchecked Sendable {
    private let log2n: vDSP_Length
    private let n: Int
    private var window: [Float]
    private let fft: vDSP.FFT<DSPSplitComplex>?

    init(log2n: Int) {
        self.log2n = vDSP_Length(log2n)
        self.n = 1 << log2n
        var w = [Float](repeating: 0, count: 1 << log2n)
        vDSP_hann_window(&w, vDSP_Length(1 << log2n), Int32(vDSP_HANN_NORM))
        self.window = w
        self.fft = vDSP.FFT(log2n: vDSP_Length(log2n), radix: .radix2, ofType: DSPSplitComplex.self)
    }

    func bandLevels(samples: [Float], bandCount: Int) -> [Float] {
        guard samples.count >= n, fft != nil else {
            return Array(repeating: 0, count: bandCount)
        }
        // 取前 n 个样本,加 Hann window 抑制边界 leakage
        var windowed = [Float](repeating: 0, count: n)
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(n))

        // vDSP.FFT 要 split complex 输入。把实数序列 pack 成 even/odd:
        // even index → real, odd index → imag (vDSP "Z" packing 标准做法)
        var real = [Float](repeating: 0, count: n / 2)
        var imag = [Float](repeating: 0, count: n / 2)
        windowed.withUnsafeBytes { ptr in
            ptr.bindMemory(to: DSPComplex.self).baseAddress.map { src in
                real.withUnsafeMutableBufferPointer { realBuf in
                    imag.withUnsafeMutableBufferPointer { imagBuf in
                        var split = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                        vDSP_ctoz(src, 2, &split, 1, vDSP_Length(n / 2))
                    }
                }
            }
        }

        // 原地 FFT
        real.withUnsafeMutableBufferPointer { realBuf in
            imag.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                fft?.forward(input: split, output: &split)
            }
        }

        // 计算每个 bin 的 magnitude
        var magnitudes = [Float](repeating: 0, count: n / 2)
        real.withUnsafeMutableBufferPointer { realBuf in
            imag.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(n / 2))
            }
        }
        // sqrt + 归一化
        var msqrt = [Float](repeating: 0, count: n / 2)
        var count = Int32(n / 2)
        vvsqrtf(&msqrt, magnitudes, &count)

        // log 频段分箱: 16 段, 30Hz~16kHz 大致跟人耳分辨率匹配。
        // bin 频率 = i * sampleRate / n; sampleRate 假设 44.1k (mixer 默认),
        // bin index 64 ~= 2.7kHz, 256 ~= 11kHz 等。直接按 bin 索引 log-spaced 分段。
        let binCount = n / 2
        var bands = [Float](repeating: 0, count: bandCount)
        let minBin = 2
        let maxBin = binCount - 1
        let logMin = log(Float(minBin))
        let logMax = log(Float(maxBin))
        let step = (logMax - logMin) / Float(bandCount)
        for b in 0..<bandCount {
            let lo = Int(exp(logMin + Float(b) * step))
            let hi = max(lo + 1, Int(exp(logMin + Float(b + 1) * step)))
            let upper = min(hi, binCount)
            var sum: Float = 0
            for i in lo..<upper { sum += msqrt[i] }
            let avg = sum / Float(max(1, upper - lo))
            // 转 dB, 截 [-60, 0], 归一化到 0...1
            let db = 20 * log10f(max(1e-7, avg))
            let clamped = max(-60, min(0, db))
            bands[b] = (clamped + 60) / 60
        }
        return bands
    }
}
