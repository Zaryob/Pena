import Foundation

/// A single stabilized snapshot of what the tuner should currently display.
public nonisolated struct TunerReading: Equatable, Sendable {
    public let frequency: Double?
    public let amplitude: Float
    public let clarity: Double
    public let isOnset: Bool

    public static let silent = TunerReading(frequency: nil, amplitude: 0, clarity: 0, isOnset: false)
}

/// Turns a raw, frame-by-frame `PitchDetectionResult` stream into a stable reading:
/// rejects low-confidence frames, ignores the pluck attack transient, filters single-frame
/// outliers, and only commits to a new note once it holds for a few consecutive frames.
///
/// Not thread-safe: confined to the single serial queue that also owns the `PitchDetector`.
public nonisolated final class PitchStabilizer: @unchecked Sendable {
    public nonisolated struct Config: Sendable {
        /// Below this YIN clarity, a frame is too ambiguous to trust.
        public var minClarity: Double
        /// Amplitude jump ratio (vs. the previous frame) that signals a fresh pluck.
        public var onsetAmplitudeRatio: Float
        /// Frames right after an onset whose pitch is discarded (attack transient noise).
        public var attackHoldFrames: Int
        /// Frames kept for the median outlier filter.
        public var historyLength: Int
        public var emaAlpha: Double
        /// Cents jump that's treated as "a different string", not drift on the same note.
        public var noteChangeCentsThreshold: Double
        /// Consecutive frames a jump must repeat before it's accepted as a note change.
        public var noteChangeConfirmFrames: Int
        /// Frames of silence/low-confidence tolerated before the reading clears to nil.
        public var silenceHoldFrames: Int

        public init(
            minClarity: Double = 0.85,
            onsetAmplitudeRatio: Float = 2.2,
            attackHoldFrames: Int = 3,
            historyLength: Int = 5,
            emaAlpha: Double = 0.35,
            noteChangeCentsThreshold: Double = 65.0,
            noteChangeConfirmFrames: Int = 3,
            silenceHoldFrames: Int = 35
        ) {
            self.minClarity = minClarity
            self.onsetAmplitudeRatio = onsetAmplitudeRatio
            self.attackHoldFrames = attackHoldFrames
            self.historyLength = historyLength
            self.emaAlpha = emaAlpha
            self.noteChangeCentsThreshold = noteChangeCentsThreshold
            self.noteChangeConfirmFrames = noteChangeConfirmFrames
            self.silenceHoldFrames = silenceHoldFrames
        }
    }

    private let config: Config
    private var recentFrequencies: [Double] = []
    private var smoothed: Double?
    private var previousAmplitude: Float = 0
    private var framesSinceOnset = Int.max
    private var silenceFrames = 0
    private var pendingCandidate: Double?
    private var pendingCandidateCount = 0

    public init(config: Config = Config()) {
        self.config = config
    }

    public func reset() {
        recentFrequencies.removeAll()
        smoothed = nil
        previousAmplitude = 0
        framesSinceOnset = .max
        silenceFrames = 0
        pendingCandidate = nil
        pendingCandidateCount = 0
    }

    /// Feed one detector result (`nil` when no periodicity was found) for the current
    /// frame's RMS amplitude and get back the reading to display.
    public func ingest(_ result: PitchDetectionResult?, rms: Float, noiseGateAmplitude: Float) -> TunerReading {
        if rms > noiseGateAmplitude, previousAmplitude > 0, rms > previousAmplitude * config.onsetAmplitudeRatio {
            framesSinceOnset = 0
            recentFrequencies.removeAll()
            pendingCandidate = nil
            pendingCandidateCount = 0
        } else if framesSinceOnset != .max {
            framesSinceOnset += 1
        }
        if rms > 0 {
            previousAmplitude = rms
        }

        guard rms >= noiseGateAmplitude, let result else {
            silenceFrames += 1
            if silenceFrames > config.silenceHoldFrames {
                reset()
                return .silent
            }
            // Sustain the last known-good pitch briefly through short dropouts (a string
            // ringing out, a momentary confidence dip) instead of flickering to silence.
            guard let smoothed else { return .silent }
            return TunerReading(frequency: smoothed, amplitude: rms, clarity: 0, isOnset: false)
        }
        silenceFrames = 0

        let isWithinAttack = framesSinceOnset < config.attackHoldFrames

        guard result.clarity >= config.minClarity, !isWithinAttack else {
            guard let smoothed else { return .silent }
            return TunerReading(frequency: smoothed, amplitude: rms, clarity: result.clarity, isOnset: isWithinAttack)
        }

        recentFrequencies.append(result.frequency)
        if recentFrequencies.count > config.historyLength {
            recentFrequencies.removeFirst()
        }
        let median = Self.median(of: recentFrequencies)

        guard let current = smoothed else {
            smoothed = median
            return TunerReading(frequency: median, amplitude: rms, clarity: result.clarity, isOnset: false)
        }

        let cents = abs(1200.0 * log2(median / current))
        guard cents > config.noteChangeCentsThreshold else {
            pendingCandidate = nil
            pendingCandidateCount = 0
            smoothed = current * (1.0 - config.emaAlpha) + median * config.emaAlpha
            return TunerReading(frequency: smoothed, amplitude: rms, clarity: result.clarity, isOnset: false)
        }

        // Large jump: only commit to a new note once it repeats for a few frames, so a
        // single spurious frame (or octave hiccup) can't yank the display to another string.
        if let pending = pendingCandidate, abs(1200.0 * log2(median / pending)) < 20.0 {
            pendingCandidateCount += 1
        } else {
            pendingCandidate = median
            pendingCandidateCount = 1
        }

        if pendingCandidateCount >= config.noteChangeConfirmFrames {
            smoothed = median
            pendingCandidate = nil
            pendingCandidateCount = 0
            return TunerReading(frequency: median, amplitude: rms, clarity: result.clarity, isOnset: true)
        }

        return TunerReading(frequency: current, amplitude: rms, clarity: result.clarity, isOnset: false)
    }

    private static func median(of values: [Double]) -> Double {
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
}
