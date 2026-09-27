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

        // 7. Parabolic interpolation on raw d(tau) around tauFound for sub-sample precision (less bias than cmndf).
        var refinedTau = Double(tauFound)
        if tauFound > 0 && tauFound + 1 < maxPeriod {
            let y1 = Double(diff[tauFound - 1])
            let y2 = Double(diff[tauFound])
            let y3 = Double(diff[tauFound + 1])
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

    /// Guards against octave errors by comparing candidates at τ0/2 and 2*τ0:
    /// - Checks τ0 / 2 to protect against shifting into a sub-octave (alt harmoniğe kaymayı önler).
    /// - Checks 2 * τ0 if τ0 was an overtone / 2nd harmonic dip and fundamental sits an octave down.
    private func correctOctaveError(tau0: Int, minPeriod: Int, maxPeriod: Int) -> Int {
        var currentTau = tau0
        let searchRadius = 2

        // 1. Sub-octave check (τ/2): If current tau0 picked up a sub-harmonic, check if τ0 / 2
        // has a valid dip close to threshold.
        let halfPeriod = tau0 / 2
        if halfPeriod - searchRadius >= minPeriod {
            var bestHalf = halfPeriod
            var bestHalfVal = cmndf[halfPeriod]
            for t in (halfPeriod - searchRadius)...min(maxPeriod - 1, halfPeriod + searchRadius) where cmndf[t] < bestHalfVal {
                bestHalfVal = cmndf[t]
                bestHalf = t
            }
            if bestHalfVal < 0.20 && (bestHalfVal < cmndf[currentTau] * 1.6 || bestHalfVal < 0.15) {
                currentTau = bestHalf
            }
        }

        // 2. Dominant harmonic check (2τ): If the fundamental is weak with a dominant 2nd harmonic,
        // τ0 will have residual error (cmndf > 0.05). If 2 * τ0 is a substantially cleaner dip, promote to 2 * τ0.
        if cmndf[currentTau] > 0.05 {
            let doublePeriod = currentTau * 2
            if doublePeriod - searchRadius >= minPeriod && doublePeriod + searchRadius < maxPeriod {
                var bestDouble = doublePeriod
                var bestDoubleVal = cmndf[doublePeriod]
                for t in (doublePeriod - searchRadius)...(doublePeriod + searchRadius) where cmndf[t] < bestDoubleVal {
                    bestDoubleVal = cmndf[t]
                    bestDouble = t
                }
                if bestDoubleVal < cmndf[currentTau] * 0.5 {
                    currentTau = bestDouble
                }
            }
        }

        return currentTau
    }
}
