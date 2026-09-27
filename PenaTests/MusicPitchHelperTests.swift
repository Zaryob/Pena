import Testing
import Foundation
@testable import Pena

@Suite("MusicPitchHelper & TuningStatus tests")
struct MusicPitchHelperTests {

    @Test("Converts standard A4 (440Hz) accurately")
    func testStandardA4() throws {
        let info = try #require(MusicPitchHelper.noteInfo(for: 440.0, a4: 440.0))
        #expect(info.noteName == "A4")
        #expect(info.solfege == "La4")
        #expect(info.octave == 4)
        #expect(abs(info.cents) < 0.001)
        #expect(abs(info.nominalFreq - 440.0) < 0.001)
    }

    @Test("Converts low E2 (~82.41Hz) accurately")
    func testLowE2() throws {
        let targetE2 = 440.0 * pow(2.0, -29.0 / 12.0)
        let info = try #require(MusicPitchHelper.noteInfo(for: targetE2, a4: 440.0))
        #expect(info.noteName == "E2")
        #expect(info.solfege == "Mi2")
        #expect(info.octave == 2)
        #expect(abs(info.cents) < 0.001)
    }

    @Test("Calculates positive cents difference when sharp")
    func testCentsDifferenceSharp() {
        let cents = MusicPitchHelper.centsDifference(frequency: 442.55, target: 440.0)
        #expect(cents > 9.9 && cents < 10.1)
    }

    @Test("Calculates negative cents difference when flat")
    func testCentsDifferenceFlat() {
        let cents = MusicPitchHelper.centsDifference(frequency: 437.46, target: 440.0)
        #expect(cents > -10.1 && cents < -9.9)
    }

    @Test("Returns nil for out-of-bounds frequencies")
    func testOutOfBoundsFrequencies() {
        #expect(MusicPitchHelper.noteInfo(for: 10.0) == nil)
        #expect(MusicPitchHelper.noteInfo(for: 5000.0) == nil)
    }
}

@Suite("TuningStatus evaluation tests")
struct TuningStatusTests {

    @Test("Evaluates in-tune correctly based on tolerance")
    func testInTuneEvaluation() {
        #expect(TuningStatus.evaluate(cents: 0.0, tolerance: 3.0) == .inTune)
        #expect(TuningStatus.evaluate(cents: 2.5, tolerance: 3.0) == .inTune)
        #expect(TuningStatus.evaluate(cents: -3.0, tolerance: 3.0) == .inTune)
    }

    @Test("Evaluates slightly sharp and sharp correctly")
    func testSharpEvaluation() {
        #expect(TuningStatus.evaluate(cents: 4.0, tolerance: 3.0) == .slightlySharp)
        #expect(TuningStatus.evaluate(cents: 10.0, tolerance: 3.0) == .slightlySharp)
        #expect(TuningStatus.evaluate(cents: 10.5, tolerance: 3.0) == .sharp)
        #expect(TuningStatus.evaluate(cents: 45.0, tolerance: 3.0) == .sharp)
    }

    @Test("Evaluates slightly flat and flat correctly")
    func testFlatEvaluation() {
        #expect(TuningStatus.evaluate(cents: -4.0, tolerance: 3.0) == .slightlyFlat)
        #expect(TuningStatus.evaluate(cents: -10.0, tolerance: 3.0) == .slightlyFlat)
        #expect(TuningStatus.evaluate(cents: -10.5, tolerance: 3.0) == .flat)
        #expect(TuningStatus.evaluate(cents: -45.0, tolerance: 3.0) == .flat)
    }

    @Test("Supports custom tolerance bands (e.g. 1.5 cents, 5.0 cents)")
    func testCustomTolerance() {
        #expect(TuningStatus.evaluate(cents: 2.0, tolerance: 1.5) == .slightlySharp)
        #expect(TuningStatus.evaluate(cents: 4.5, tolerance: 5.0) == .inTune)
    }
}
