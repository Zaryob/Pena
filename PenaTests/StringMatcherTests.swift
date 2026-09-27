import Testing
import Foundation
@testable import Pena

@Suite("StringMatcher & Hysteresis tests")
struct StringMatcherTests {

    @Test("Matches closest string when starting from cold state")
    @MainActor
    func matchesClosestStringFromCold() {
        let vm = TunerViewModel()
        vm.currentPreset = .standard
        vm.tuningMode = .auto

        // Feed A2 (110 Hz)
        vm.updateAutoDetection(frequency: 110.0)

        #expect(vm.activeString.id == 5) // 5. Tel (A2)
        #expect(vm.activeString.noteName == "A2")
    }

    @Test("Ignores frequencies outside valid string proximity (>220 cents)")
    @MainActor
    func ignoresFarFrequencies() {
        let vm = TunerViewModel()
        vm.currentPreset = .standard
        vm.tuningMode = .auto

        // Initial match to E2 (82.4 Hz)
        vm.updateAutoDetection(frequency: 82.4)
        #expect(vm.activeString.id == 6)

        // Random whistle or noise at 600 Hz (far beyond E4 at 329.6 Hz)
        vm.updateAutoDetection(frequency: 600.0)
        #expect(vm.activeString.id == 6) // Preserves current string without jumping
    }

    @Test("Applies hysteresis: rejects jump if candidate is not at least 40 cents closer")
    @MainActor
    func appliesHysteresisDistanceThreshold() {
        let vm = TunerViewModel()
        vm.currentPreset = .standard
        vm.tuningMode = .auto

        // Lock onto D3 (146.83 Hz, id 4)
        vm.updateAutoDetection(frequency: 146.83)
        #expect(vm.activeString.id == 4)

        // Frequency halfway between D3 (146.83 Hz) and G3 (196.00 Hz)
        // 5 semitones between D3 and G3 = 500 cents.
        // At 240 cents from D3 and 260 cents from G3, G3 is closer by only 20 cents (< 40 cents margin)
        let midFreq = 146.83 * pow(2.0, 2.4 / 12.0)
        vm.updateAutoDetection(frequency: midFreq)
        vm.updateAutoDetection(frequency: midFreq)

        // Should NOT switch to G3 because delta is < 40 cents
        #expect(vm.activeString.id == 4)
    }

    @Test("Applies debounce: requires 2 consecutive frames before switching string")
    @MainActor
    func appliesTwoFrameDebounce() {
        let vm = TunerViewModel()
        vm.currentPreset = .standard
        vm.tuningMode = .auto

        // Lock onto E2 (82.4 Hz, id 6)
        vm.updateAutoDetection(frequency: 82.4)
        #expect(vm.activeString.id == 6)

        // Now play clear B3 (246.94 Hz, id 2)
        // Frame 1: candidate registered but not yet committed
        vm.updateAutoDetection(frequency: 246.94)
        #expect(vm.activeString.id == 6)

        // Frame 2: candidate confirmed and committed
        vm.updateAutoDetection(frequency: 246.94)
        #expect(vm.activeString.id == 2)
    }

    @Test("Resets debounce when candidate readings are not consecutive")
    @MainActor
    func resetsDebounceAfterMissingReading() {
        let vm = TunerViewModel()
        vm.currentPreset = .standard
        vm.tuningMode = .auto

        vm.updateAutoDetection(frequency: 82.4)
        vm.updateAutoDetection(frequency: 246.94)
        vm.updateAutoDetection(frequency: nil)
        vm.updateAutoDetection(frequency: 246.94)

        #expect(vm.activeString.id == 6)

        vm.updateAutoDetection(frequency: 246.94)
        #expect(vm.activeString.id == 2)
    }

    @Test("Ignores non-finite and non-positive frequencies")
    @MainActor
    func ignoresInvalidFrequencies() {
        let vm = TunerViewModel()
        vm.currentPreset = .standard
        vm.tuningMode = .auto

        vm.updateAutoDetection(frequency: 110.0)
        vm.updateAutoDetection(frequency: .nan)
        vm.updateAutoDetection(frequency: .infinity)
        vm.updateAutoDetection(frequency: 0)
        vm.updateAutoDetection(frequency: -82.4)

        #expect(vm.activeString.id == 5)
    }
}
