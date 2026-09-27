import Testing
import Foundation
@testable import Pena

@Suite("PitchDetector accuracy")
struct PitchDetectorTests {

    /// Synthesizes a plucked-string-like signal: a fundamental plus a harmonic series,
    /// optionally with a touch of noise to emulate a real microphone recording.
    static func syntheticString(
        frequency: Double,
        sampleRate: Double,
        count: Int,
        harmonicAmplitudes: [Double] = [1.0, 0.5, 0.28, 0.15, 0.08],
        noiseAmplitude: Double = 0.02
    ) -> [Float] {
        var samples = [Float](repeating: 0, count: count)
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func nextNoise() -> Double {
            // Deterministic xorshift so tests are reproducible.
            seed ^= seed << 13
            seed ^= seed >> 7
            seed ^= seed << 17
            return (Double(seed % 2000) / 1000.0) - 1.0
        }

        let twoPi = 2.0 * Double.pi
        for i in 0..<count {
            let t = Double(i) / sampleRate
            var value = 0.0
            for (index, amplitude) in harmonicAmplitudes.enumerated() {
                let harmonic = Double(index + 1)
                value += amplitude * sin(twoPi * frequency * harmonic * t)
            }
            let noise = noiseAmplitude * nextNoise()
            samples[i] = Float((value + noise) * 0.2)
        }
        return samples
    }

    /// Synthetic nylon guitar string: fundamental + exponentially decaying harmonics + damping envelope + SNR 20dB white noise.
    static func syntheticNylonString(
        frequency: Double,
        sampleRate: Double,
        count: Int
    ) -> [Float] {
        var samples = [Float](repeating: 0, count: count)
        let twoPi = 2.0 * Double.pi
        let harmonics = [1.0, 0.55, 0.30, 0.18, 0.10, 0.05]
        var seed: UInt64 = 0x8543789421A4B
        func nextNoise() -> Double {
            seed ^= seed << 13
            seed ^= seed >> 7
            seed ^= seed << 17
            return (Double(seed % 2000) / 1000.0) - 1.0
        }

        let noiseAmp = 0.02
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let damping = exp(-1.2 * t)
            var val = 0.0
            for (hIdx, amp) in harmonics.enumerated() {
                let harmonic = Double(hIdx + 1)
                val += amp * sin(twoPi * frequency * harmonic * t)
            }
            let noise = nextNoise() * noiseAmp
            samples[i] = Float((val * damping + noise) * 0.25)
        }
        return samples
    }

    @Test("Detects every standard-tuning string within 1 cent", arguments: TuningPreset.standard.strings)
    func detectsStandardStrings(_ string: GuitarString) throws {
        let sampleRate = 48000.0
        let detector = PitchDetector()
        let targetFreq = string.targetFrequency(a4: 440.0)
        let samples = Self.syntheticString(frequency: targetFreq, sampleRate: sampleRate, count: PitchDetector.windowSize)
        let config = PitchDetectorConfig(minFrequency: 60.0, maxFrequency: 420.0)

        let result = try #require(detector.detectPitch(samples: samples, sampleRate: sampleRate, rms: 0.1, config: config))
        let cents = 1200.0 * log2(result.frequency / targetFreq)
        #expect(abs(cents) < 1.0, "Expected \(targetFreq) Hz, got \(result.frequency) Hz (\(cents) cents off)")
        #expect(result.clarity > 0.85)
    }

    struct PresetStringCase: CustomTestStringConvertible {
        let presetId: String
        let string: GuitarString

        var testDescription: String {
            "\(presetId): \(string.noteName) (\(string.targetFrequency(a4: 440.0).formatted(.number.precision(.fractionLength(1)))) Hz)"
        }
    }

    static var allPresetCases: [PresetStringCase] {
        var list: [PresetStringCase] = []
        for preset in TuningPreset.allPresets {
            for string in preset.strings {
                list.append(PresetStringCase(presetId: preset.id, string: string))
            }
        }
        return list
    }

    @Test("Detects every preset string within 1 cent", arguments: allPresetCases)
    func detectsAllPresetStrings(_ item: PresetStringCase) throws {
        let sampleRate = 48000.0
        let detector = PitchDetector()
        let targetFreq = item.string.targetFrequency(a4: 440.0)
        let samples = Self.syntheticNylonString(frequency: targetFreq, sampleRate: sampleRate, count: PitchDetector.windowSize)
        let config = PitchDetectorConfig(minFrequency: 55.0, maxFrequency: 450.0)

        let result = try #require(detector.detectPitch(samples: samples, sampleRate: sampleRate, rms: 0.1, config: config))
        let cents = 1200.0 * log2(result.frequency / targetFreq)
        #expect(abs(cents) < 1.0, "Expected \(targetFreq) Hz, got \(result.frequency) Hz (\(cents) cents off)")
        #expect(result.clarity > 0.80)
    }

    @Test("Detects detuned strings at the correct offset", arguments: [-25.0, -10.0, 10.0, 25.0])
    func detectsDetunedOffsets(_ offsetCents: Double) throws {
        let sampleRate = 48000.0
        let detector = PitchDetector()
        let baseFreq = TuningPreset.standard.strings.first { $0.id == 6 }!.targetFrequency(a4: 440.0) // E2
        let detunedFreq = baseFreq * pow(2.0, offsetCents / 1200.0)
        let samples = Self.syntheticString(frequency: detunedFreq, sampleRate: sampleRate, count: PitchDetector.windowSize)
        let config = PitchDetectorConfig(minFrequency: 60.0, maxFrequency: 420.0)

        let result = try #require(detector.detectPitch(samples: samples, sampleRate: sampleRate, rms: 0.1, config: config))
        let cents = 1200.0 * log2(result.frequency / detunedFreq)
        #expect(abs(cents) < 1.0)
    }

    @Test("Works at both 44.1kHz and 48kHz", arguments: [44100.0, 48000.0])
    func detectsAcrossSampleRates(_ sampleRate: Double) throws {
        let detector = PitchDetector()
        let targetFreq = 110.0 // A2
        let samples = Self.syntheticString(frequency: targetFreq, sampleRate: sampleRate, count: PitchDetector.windowSize)
        let config = PitchDetectorConfig(minFrequency: 60.0, maxFrequency: 420.0)

        let result = try #require(detector.detectPitch(samples: samples, sampleRate: sampleRate, rms: 0.1, config: config))
        let cents = 1200.0 * log2(result.frequency / targetFreq)
        #expect(abs(cents) < 1.0)
    }

    @Test("Detects strings across different A4 calibrations (415, 440, 442 Hz)", arguments: [415.0, 440.0, 442.0])
    func detectsDifferentA4Calibrations(_ a4: Double) throws {
        let sampleRate = 48000.0
        let detector = PitchDetector()
        let string = TuningPreset.standard.strings.first { $0.id == 5 }! // A2
        let targetFreq = string.targetFrequency(a4: a4)
        let samples = Self.syntheticNylonString(frequency: targetFreq, sampleRate: sampleRate, count: PitchDetector.windowSize)
        let config = PitchDetectorConfig(minFrequency: 60.0, maxFrequency: 420.0)

        let result = try #require(detector.detectPitch(samples: samples, sampleRate: sampleRate, rms: 0.1, config: config))
        let cents = 1200.0 * log2(result.frequency / targetFreq)
        #expect(abs(cents) < 1.0)
    }

    @Test("A weak fundamental with a dominant 2nd harmonic still resolves to the true pitch")
    func weakFundamentalDoesNotCauseOctaveError() throws {
        let sampleRate = 48000.0
        let detector = PitchDetector()
        let targetFreq = 110.0 // A2
        let samples = Self.syntheticString(
            frequency: targetFreq,
            sampleRate: sampleRate,
            count: PitchDetector.windowSize,
            harmonicAmplitudes: [0.12, 1.0, 0.3, 0.15],
            noiseAmplitude: 0.0
        )
        let config = PitchDetectorConfig(minFrequency: 60.0, maxFrequency: 420.0)

        let result = try #require(detector.detectPitch(samples: samples, sampleRate: sampleRate, rms: 0.1, config: config))
        let cents = 1200.0 * log2(result.frequency / targetFreq)
        #expect(abs(cents) < 5.0, "Locked onto \(result.frequency) Hz instead of the \(targetFreq) Hz fundamental")
    }

    @Test("Simulates phone microphone frequency response (attenuated low fundamental)")
    func detectsAttenuatedPhoneMicFundamental() throws {
        let sampleRate = 48000.0
        let detector = PitchDetector()
        let targetFreq = 82.4069 // E2
        let samples = Self.syntheticString(
            frequency: targetFreq,
            sampleRate: sampleRate,
            count: PitchDetector.windowSize,
            harmonicAmplitudes: [0.25, 1.0, 0.6, 0.35, 0.2],
            noiseAmplitude: 0.02
        )
        let config = PitchDetectorConfig(minFrequency: 60.0, maxFrequency: 420.0)

        let result = try #require(detector.detectPitch(samples: samples, sampleRate: sampleRate, rms: 0.1, config: config))
        let cents = 1200.0 * log2(result.frequency / targetFreq)
        #expect(abs(cents) < 1.0, "Expected \(targetFreq) Hz, got \(result.frequency) Hz (\(cents) cents off)")
    }

    @Test("Returns nil for silence")
    func returnsNilForSilence() {
        let detector = PitchDetector()
        let samples = [Float](repeating: 0, count: PitchDetector.windowSize)
        let config = PitchDetectorConfig(minFrequency: 60.0, maxFrequency: 420.0)
        #expect(detector.detectPitch(samples: samples, sampleRate: 48000.0, rms: 0.0, config: config) == nil)
    }

    @Test("Rejects a window of the wrong sample count")
    func rejectsWrongSampleCount() {
        let detector = PitchDetector()
        let samples = [Float](repeating: 0, count: PitchDetector.windowSize - 1)
        let config = PitchDetectorConfig(minFrequency: 60.0, maxFrequency: 420.0)
        #expect(detector.detectPitch(samples: samples, sampleRate: 48000.0, rms: 0.1, config: config) == nil)
    }

    @Test(
        "Rejects invalid detector configuration",
        arguments: [
            PitchDetectorConfig(minFrequency: 0, maxFrequency: 420),
            PitchDetectorConfig(minFrequency: 420, maxFrequency: 60),
            PitchDetectorConfig(minFrequency: .infinity, maxFrequency: 420),
            PitchDetectorConfig(minFrequency: 60, maxFrequency: .nan),
            PitchDetectorConfig(minFrequency: 60, maxFrequency: 420, yinThreshold: 0),
            PitchDetectorConfig(minFrequency: 60, maxFrequency: 420, yinThreshold: 1.1)
        ]
    )
    func rejectsInvalidConfiguration(_ config: PitchDetectorConfig) {
        let detector = PitchDetector()
        let samples = [Float](repeating: 0, count: PitchDetector.windowSize)

        #expect(detector.detectPitch(samples: samples, sampleRate: 48000.0, rms: 0.1, config: config) == nil)
    }

    @Test("Rejects invalid sample rates", arguments: [0.0, -48000.0, .infinity, .nan])
    func rejectsInvalidSampleRate(_ sampleRate: Double) {
        let detector = PitchDetector()
        let samples = [Float](repeating: 0, count: PitchDetector.windowSize)
        let config = PitchDetectorConfig(minFrequency: 60.0, maxFrequency: 420.0)

        #expect(detector.detectPitch(samples: samples, sampleRate: sampleRate, rms: 0.1, config: config) == nil)
    }
}
