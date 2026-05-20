import Accelerate
import AVFoundation
import Foundation
import os.lock

/// 实时音频频谱可视化器 —— 在 AudioEngine 的 mainMixerNode 上挂 tap, 拿到
/// 输出 buffer 做 FFT, 把 1024 点频谱压成 16 个频段强度发布给 UI。
///
/// **音频线程安全**:
/// tap callback 跑在音频实时线程, 严格限制只做 memcpy + 翻 atomic flag,
/// 不允许 Swift Array 分配 / 类型绑定 / FFT / MainActor hop ── 这些都会把
/// 音频线程拖慢甚至抢占,在 iOS 26 上会触发硬崩溃。FFT + 发布到 UI 全部
/// 在另起的 background Task 里跑。
///
/// 启停语义:
/// - `start(engine:on:)` 在 NowPlayingView onAppear 时调,绑定到当前的
///   AVAudioEngine。
/// - `stop()` 在 NowPlayingView onDisappear / 后台 时调,卸 tap, 释放计算资源。
@MainActor
@Observable
final class AudioVisualizerService {
    // nonisolated 让 detached Task 和 SwiftUI 视图都能直接读, 不用 hop main actor。
    nonisolated static let bandCount = 16
    nonisolated static let fftSize = 1024

    /// 0...1 归一化的频段强度。bandLevels.count == bandCount 永远成立。
    /// UI 用 .animation(.linear(duration: 0.07), value: bandLevels) 即可平滑过渡。
    private(set) var bandLevels: [Float] = Array(repeating: 0, count: bandCount)

    private weak var engine: AVAudioEngine?
    private var tappedNode: AVAudioMixerNode?
    private let buffer = SharedSampleBuffer(capacity: fftSize)
    private var pollTask: Task<Void, Never>?

    func start(engine: AVAudioEngine, on node: AVAudioMixerNode) {
        if let tappedNode {
            guard tappedNode !== node else { return }
            stop()
        }

        guard engine.isRunning else { return }

        let format = node.outputFormat(forBus: 0)
        guard format.sampleRate.isFinite,
              format.sampleRate > 0,
              format.channelCount > 0 else {
            plog("⚠️ Visualizer skipped: invalid mixer format sr=\(format.sampleRate) ch=\(format.channelCount)")
            return
        }

        self.engine = engine

        // tap 闭包只 memcpy + 翻 flag, 完全不 alloc 不 hop actor。
        let buffer = self.buffer
        AudioVisualizerTap.install(
            on: node,
            bufferSize: AVAudioFrameCount(Self.fftSize),
            format: format,
            buffer: buffer
        )
        self.tappedNode = node

        // 用 detached Task 周期性拉 buffer 做 FFT, 跟音频线程完全解耦。
        // 25Hz 节流, 落到 main actor 才更新 @Observable bandLevels。
        let analyzer = FFTAnalyzer(log2n: Int(log2(Double(Self.fftSize))))
        pollTask = Task.detached(priority: .userInitiated) { [weak self, buffer, analyzer] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(40))
                guard !Task.isCancelled else { break }
                guard let samples = buffer.consumeIfReady() else { continue }
                let levels = analyzer.bandLevels(samples: samples, bandCount: Self.bandCount)
                await MainActor.run { [weak self] in
                    self?.bandLevels = levels
                }
            }
        }
    }

    func stop() {
        pollTask?.cancel(); pollTask = nil
        if let node = tappedNode {
            node.removeTap(onBus: 0)
        }
        tappedNode = nil
        engine = nil
        bandLevels = Array(repeating: 0, count: Self.bandCount)
    }
}

/// `installTap` must be created outside the `@MainActor` visualizer service.
/// Otherwise Swift can inherit MainActor isolation for the tap closure, and
/// AVAudioEngine will trip the iOS 26 concurrency runtime when it invokes the
/// closure on Core Audio's realtime queue.
private enum AudioVisualizerTap {
    static func install(
        on node: AVAudioMixerNode,
        bufferSize: AVAudioFrameCount,
        format: AVAudioFormat,
        buffer: SharedSampleBuffer
    ) {
        node.installTap(onBus: 0, bufferSize: bufferSize, format: format) { audioBuffer, _ in
            buffer.fill(from: audioBuffer)
        }
    }
}

// MARK: - Audio-thread-safe sample buffer

/// 共享缓冲: 音频线程写,后台 Task 读。用 os_unfair_lock 替代 Swift actor —
/// actor hop 在音频线程不允许。Lock 失败时直接 drop frame (轮询 tick 下一帧
/// 会取最新数据)。
private final class SharedSampleBuffer: @unchecked Sendable {
    private var data: [Float]
    private var hasFresh = false
    private var lock = os_unfair_lock_s()
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        self.data = Array(repeating: 0, count: capacity)
    }

    /// 音频线程调用。AVAudioPCMBuffer 第 0 声道前 capacity 个样本拷进 data。
    /// 失败 (锁忙 / 格式不对) 直接返回, 不在音频线程做任何复杂的事。
    func fill(from buffer: AVAudioPCMBuffer) {
        guard let ch = buffer.floatChannelData else { return }
        let frames = min(Int(buffer.frameLength), capacity)
        guard frames > 0 else { return }
        guard os_unfair_lock_trylock(&lock) else { return }  // 锁忙就放弃这一帧
        data.withUnsafeMutableBufferPointer { dst in
            guard let base = dst.baseAddress else { return }
            memcpy(base, ch[0], frames * MemoryLayout<Float>.size)
            if frames < capacity {
                // 不足 capacity 时把尾部置零, FFT 自然就少高频能量, 视觉上正常
                memset(base.advanced(by: frames), 0, (capacity - frames) * MemoryLayout<Float>.size)
            }
        }
        hasFresh = true
        os_unfair_lock_unlock(&lock)
    }

    /// 后台 Task 调用。有新数据时返回 snapshot, 否则 nil。
    func consumeIfReady() -> [Float]? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        guard hasFresh else { return nil }
        hasFresh = false
        return data
    }
}

// MARK: - FFT analyzer (跑在 background Task, 不在音频线程)

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
        var windowed = [Float](repeating: 0, count: n)
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(n))

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

        real.withUnsafeMutableBufferPointer { realBuf in
            imag.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                fft?.forward(input: split, output: &split)
            }
        }

        var magnitudes = [Float](repeating: 0, count: n / 2)
        real.withUnsafeMutableBufferPointer { realBuf in
            imag.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(n / 2))
            }
        }
        var msqrt = [Float](repeating: 0, count: n / 2)
        var count = Int32(n / 2)
        vvsqrtf(&msqrt, magnitudes, &count)

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
            let db = 20 * log10f(max(1e-7, avg))
            let clamped = max(-60, min(0, db))
            bands[b] = (clamped + 60) / 60
        }
        return bands
    }
}
