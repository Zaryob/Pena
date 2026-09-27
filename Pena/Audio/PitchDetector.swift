import Foundation
import Accelerate

// MARK: - Pitch Detection Result
public nonisolated struct PitchDetectionResult: Equatable, Sendable {
    public let frequency: Double
    public let amplitude: Float
    public let clarity: Double

    public init(frequency: Double, amplitude: Float, clarity: Double) {
        self.frequency = frequency
        self.amplitude = amplitude
        self.clarity = clarity
    }
}

// MARK: - Detector Configuration
public nonisolated struct PitchDetectorConfig: Sendable, Equatable {
    public var minFrequency: Double
    public var maxFrequency: Double
    public var yinThreshold: Float

    public init(minFrequency: Double = 65.0, maxFrequency: Double = 420.0, yinThreshold: Float = 0.15) {
        self.minFrequency = minFrequency
        self.maxFrequency = maxFrequency
        self.yinThreshold = yinThreshold
    }
}

/// Instrument-agnostic YIN pitch detector with reusable, fixed-size scratch buffers.
///
/// Not thread-safe: instances are meant to be owned and driven exclusively by a single
/// serial analysis queue (never the real-time audio render thread) so that the heavy,
/// allocation-free math here never competes with `AVAudioEngine`'s render deadline.
public nonisolated final class PitchDetector: @unchecked Sendable {
    /// Analysis window length in samples. At 48kHz this is ~85ms, giving the lowest
    /// classical guitar string (E2, 82.4Hz) more than 5 full periods to correlate against,
    /// which keeps the difference function from being dominated by edge effects.
    public static let windowSize = 4096

    private let n = PitchDetector.windowSize
    private var centered: [Float]
    private var xcorr: [Float]
    private var diff: [Float]
    private var cmndf: [Float]
    private var cumulativeEnergy: [Float]

    public init() {
        centered = [Float](repeating: 0, count: n)
        xcorr = [Float](repeating: 0, count: n)
        diff = [Float](repeating: 0, count: n)
        cmndf = [Float](repeating: 0, count: n)
        cumulativeEnergy = [Float](repeating: 0, count: n + 1)
    }

    /// `samples` must contain exactly `PitchDetector.windowSize` values.
    public func detectPitch(
        samples: [Float],
        sampleRate: Double,
        rms: Float,
        config: PitchDetectorConfig
    ) -> PitchDetectionResult? {
        guard samples.count == n, sampleRate > 0 else { return nil }

        // 1. Remove DC offset into the reusable `centered` buffer (no allocation).
        var mean: Float = 0
        vDSP_meanv(samples, 1, &mean, vDSP_Length(n))
        var negMean = -mean
        vDSP_vsadd(samples, 1, &negMean, &centered, 1, vDSP_Length(n))

        let minPeriod = max(2, Int(sampleRate / config.maxFrequency))
        let maxPeriod = min(n / 2, Int(sampleRate / config.minFrequency))
        let windowLength = n - maxPeriod
        guard maxPeriod > minPeriod + 1, windowLength > minPeriod * 2 else { return nil }

        // 2. Cumulative energy prefix sums replace the O(maxPeriod * windowLength) calls
        //    to vDSP_svesq that a naive per-tau energy computation would require; each
        //    windowed energy(tau) becomes an O(1) subtraction instead.
        cumulativeEnergy[0] = 0
        centered.withUnsafeBufferPointer { buf in
            for i in 0..<n {
                let v = buf[i]
                cumulativeEnergy[i + 1] = cumulativeEnergy[i] + v * v
            }
        }
        func windowEnergy(_ tau: Int) -> Float {
            cumulativeEnergy[tau + windowLength] - cumulativeEnergy[tau]
        }
        let energy0 = windowEnergy(0)

        // 3. Cross-correlation via vDSP_conv.
        centered.withUnsafeBufferPointer { s in
            xcorr.withUnsafeMutableBufferPointer { x in
                vDSP_conv(s.baseAddress!, 1, s.baseAddress!, 1, x.baseAddress!, 1, vDSP_Length(maxPeriod), vDSP_Length(windowLength))
            }
        }

        // 4. YIN difference function d(tau) = energy0 + energy(tau) - 2 * xcorr(tau).
        diff[0] = 0
        for tau in 1..<maxPeriod {
            diff[tau] = max(0, energy0 + windowEnergy(tau) - 2.0 * xcorr[tau])
        }

        // 5. Cumulative Mean Normalized Difference Function.
        cmndf[0] = 1.0
        var runningSum: Float = 0
        for tau in 1..<maxPeriod {
            runningSum += diff[tau]
            cmndf[tau] = runningSum > 1e-9 ? diff[tau] * Float(tau) / runningSum : 1.0
        }

        // 6. Absolute thresholding: take the first dip below threshold, refined to its
        //    local minimum. Scanning from the smallest tau (highest frequency) first is
        //    what protects against "octave too low" errors.
        var bestTau: Int? = nil
        var tau = minPeriod
        while tau < maxPeriod {
            if cmndf[tau] < config.yinThreshold {
                var localMin = tau
                while localMin + 1 < maxPeriod && cmndf[localMin + 1] <= cmndf[localMin] {
                    localMin += 1
                }
                bestTau = localMin
                break
            }
            tau += 1
        }

        // Fallback: no clean dip found below the strict threshold; accept the global
        // minimum only if it's still a reasonably confident periodicity match.
        if bestTau == nil {
            var minVal: Float = .greatestFiniteMagnitude
            var minTau: Int? = nil
            for t in minPeriod..<maxPeriod where cmndf[t] < minVal {
                minVal = cmndf[t]
                minTau = t
            }
            if minVal < 0.4, let mt = minTau {
                bestTau = mt
            }
        }

        guard var tauFound = bestTau else { return nil }
        tauFound = correctOctaveError(tau0: tauFound, minPeriod: minPeriod, maxPeriod: maxPeriod)

        // 7. Parabolic interpolation on cmndf around tauFound for sub-sample precision.
        var refinedTau = Double(tauFound)
        if tauFound > 0 && tauFound + 1 < maxPeriod {
            let y1 = Double(cmndf[tauFound - 1])
            let y2 = Double(cmndf[tauFound])
            let y3 = Double(cmndf[tauFound + 1])
            let denom = 2.0 * (2.0 * y2 - y1 - y3)
            if abs(denom) > 1e-12 {
                let shift = (y3 - y1) / denom
                if abs(shift) < 1.0 {
                    refinedTau += shift
                }
            }
        }
        guard refinedTau > 0 else { return nil }

        let frequency = sampleRate / refinedTau
        guard frequency >= config.minFrequency * 0.5, frequency <= config.maxFrequency * 2.0 else { return nil }

        let clarity = max(0.0, min(1.0, 1.0 - Double(cmndf[tauFound])))
        return PitchDetectionResult(frequency: frequency, amplitude: rms, clarity: clarity)
    }

    /// Guards against the common "octave too high" failure mode where a plucked string's
    /// strong 2nd harmonic creates a spurious, near-perfect periodicity dip at half the
    /// true period. A genuine fundamental at `tau0` is, by definition, already the
    /// smallest period the signal repeats with, so a *materially deeper* dip near
    /// `2 * tau0` (not just "also below threshold", which every multiple of a true
    /// period trivially satisfies) is evidence that `tau0` was actually the harmonic
    /// and the real fundamental sits an octave down.
    private func correctOctaveError(tau0: Int, minPeriod: Int, maxPeriod: Int) -> Int {
        let center = tau0 * 2
        let searchRadius = 2
        guard center - searchRadius >= minPeriod, center + searchRadius < maxPeriod else { return tau0 }

        var bestTau = center
        var bestVal = cmndf[center]
        for t in (center - searchRadius)...(center + searchRadius) where cmndf[t] < bestVal {
            bestVal = cmndf[t]
            bestTau = t
        }

        if bestVal < cmndf[tau0] * 0.8 {
            return bestTau
        }
        return tau0
    }
}
