import Testing
@testable import Pena

@Suite("PitchStabilizer")
struct PitchStabilizerTests {

    @Test("Ignores the attack transient right after an onset")
    func ignoresAttackTransient() {
        let stabilizer = PitchStabilizer(config: .init(minClarity: 0.5, attackHoldFrames: 3, silenceHoldFrames: 100))

        // Prime a quiet ambient baseline so the next loud frame reads as a genuine onset.
        _ = stabilizer.ingest(nil, rms: 0.002, noiseGateAmplitude: 0.01)

        let onset = stabilizer.ingest(PitchDetectionResult(frequency: 999.0, amplitude: 0.5, clarity: 0.9), rms: 0.5, noiseGateAmplitude: 0.01)
        #expect(onset.frequency == nil)

        for _ in 0..<2 {
            let reading = stabilizer.ingest(PitchDetectionResult(frequency: 110.0, amplitude: 0.3, clarity: 0.95), rms: 0.3, noiseGateAmplitude: 0.01)
            #expect(reading.frequency == nil)
        }

        let settled = stabilizer.ingest(PitchDetectionResult(frequency: 110.0, amplitude: 0.3, clarity: 0.95), rms: 0.3, noiseGateAmplitude: 0.01)
        let frequency = try? #require(settled.frequency)
        #expect(frequency != nil)
        if let frequency {
            #expect(abs(frequency - 110.0) < 0.5)
        }
    }

    @Test("Rejects a single-frame outlier without disturbing the smoothed pitch")
    func rejectsOutlier() {
        let stabilizer = PitchStabilizer(config: .init(minClarity: 0.5, attackHoldFrames: 0, historyLength: 5, silenceHoldFrames: 100))
        for _ in 0..<5 {
            _ = stabilizer.ingest(PitchDetectionResult(frequency: 110.0, amplitude: 0.3, clarity: 0.95), rms: 0.3, noiseGateAmplitude: 0.01)
        }

        let outlierReading = stabilizer.ingest(PitchDetectionResult(frequency: 800.0, amplitude: 0.3, clarity: 0.95), rms: 0.3, noiseGateAmplitude: 0.01)
        let frequency = outlierReading.frequency
        #expect(frequency != nil)
        if let frequency {
            #expect(abs(frequency - 110.0) < 5.0, "A single outlier frame shifted the reading to \(frequency) Hz")
        }
    }

    @Test("Commits to a new note only after it holds for several consecutive frames")
    func debouncesNoteChange() {
        let stabilizer = PitchStabilizer(config: .init(
            minClarity: 0.5,
            attackHoldFrames: 0,
            historyLength: 1,
            noteChangeCentsThreshold: 65.0,
            noteChangeConfirmFrames: 3,
            silenceHoldFrames: 100
        ))
        for _ in 0..<3 {
            _ = stabilizer.ingest(PitchDetectionResult(frequency: 110.0, amplitude: 0.3, clarity: 0.95), rms: 0.3, noiseGateAmplitude: 0.01)
        }

        // A jump to another string shouldn't switch on the first frame...
        let firstJump = stabilizer.ingest(PitchDetectionResult(frequency: 146.83, amplitude: 0.3, clarity: 0.95), rms: 0.3, noiseGateAmplitude: 0.01)
        if let frequency = firstJump.frequency {
            #expect(abs(frequency - 110.0) < 1.0)
        }

        // ...but should commit once it repeats for `noteChangeConfirmFrames` frames.
        _ = stabilizer.ingest(PitchDetectionResult(frequency: 146.83, amplitude: 0.3, clarity: 0.95), rms: 0.3, noiseGateAmplitude: 0.01)
        let confirmed = stabilizer.ingest(PitchDetectionResult(frequency: 146.83, amplitude: 0.3, clarity: 0.95), rms: 0.3, noiseGateAmplitude: 0.01)
        let frequency = confirmed.frequency
        #expect(frequency != nil)
        if let frequency {
            #expect(abs(frequency - 146.83) < 1.0)
        }
        #expect(confirmed.isOnset)
    }

    @Test("Clears to nil after sustained silence")
    func clearsAfterSilence() {
        let stabilizer = PitchStabilizer(config: .init(minClarity: 0.5, attackHoldFrames: 0, silenceHoldFrames: 3))
        _ = stabilizer.ingest(PitchDetectionResult(frequency: 110.0, amplitude: 0.3, clarity: 0.95), rms: 0.3, noiseGateAmplitude: 0.01)

        var last = TunerReading.silent
        for _ in 0..<5 {
            last = stabilizer.ingest(nil, rms: 0.0, noiseGateAmplitude: 0.01)
        }
        #expect(last.frequency == nil)
    }

    @Test("Reset clears all internal state")
    func resetClearsState() {
        let stabilizer = PitchStabilizer(config: .init(minClarity: 0.5, attackHoldFrames: 0, silenceHoldFrames: 100))
        _ = stabilizer.ingest(PitchDetectionResult(frequency: 110.0, amplitude: 0.3, clarity: 0.95), rms: 0.3, noiseGateAmplitude: 0.01)
        stabilizer.reset()

        let afterReset = stabilizer.ingest(nil, rms: 0.0, noiseGateAmplitude: 0.01)
        #expect(afterReset.frequency == nil)
    }
}
