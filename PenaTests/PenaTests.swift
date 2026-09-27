//
//  PenaTests.swift
//  PenaTests
//
//  Created by Süleyman Poyraz on 27.09.2026.
//

import Foundation
import Testing
@testable import Pena

@Suite("Tuner settings", .serialized)
struct TunerSettingsTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "TunerSettingsTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    @Test("Persists user-configurable tuner settings")
    @MainActor
    func persistsSettings() {
        let defaults = makeDefaults()
        let viewModel = TunerViewModel(defaults: defaults)

        viewModel.currentPreset = .dropD
        viewModel.tuningMode = .manual
        viewModel.notationStyle = .solfege
        viewModel.a4Frequency = 442
        viewModel.inTuneTolerance = 5
        viewModel.sensitivity = .noisy

        #expect(defaults.string(forKey: "pena.presetID") == TuningPreset.dropD.id)
        #expect(defaults.string(forKey: "pena.tuningMode") == TuningMode.manual.rawValue)
        #expect(defaults.string(forKey: "pena.notationStyle") == NotationStyle.solfege.rawValue)
        #expect(defaults.double(forKey: "pena.a4Frequency") == 442)
        #expect(defaults.double(forKey: "pena.inTuneTolerance") == 5)
        #expect(defaults.string(forKey: "pena.sensitivity") == ListeningSensitivity.noisy.rawValue)
    }

    @Test("Restores previously saved settings")
    @MainActor
    func restoresSettings() {
        let defaults = makeDefaults()
        defaults.set(TuningPreset.dadgad.id, forKey: "pena.presetID")
        defaults.set(TuningMode.manual.rawValue, forKey: "pena.tuningMode")
        defaults.set(NotationStyle.solfege.rawValue, forKey: "pena.notationStyle")
        defaults.set(415.0, forKey: "pena.a4Frequency")
        defaults.set(2.0, forKey: "pena.inTuneTolerance")
        defaults.set(ListeningSensitivity.quiet.rawValue, forKey: "pena.sensitivity")

        let viewModel = TunerViewModel(defaults: defaults)

        #expect(viewModel.currentPreset.id == TuningPreset.dadgad.id)
        #expect(viewModel.tuningMode == .manual)
        #expect(viewModel.notationStyle == .solfege)
        #expect(viewModel.a4Frequency == 415)
        #expect(viewModel.inTuneTolerance == 2)
        #expect(viewModel.sensitivity == .quiet)
    }

    @Test("Rejects corrupt persisted and runtime numeric settings")
    @MainActor
    func rejectsInvalidNumericSettings() {
        let defaults = makeDefaults()
        defaults.set(Double.nan, forKey: "pena.a4Frequency")
        defaults.set(-1.0, forKey: "pena.inTuneTolerance")

        let viewModel = TunerViewModel(defaults: defaults)
        #expect(viewModel.a4Frequency == 440)
        #expect(viewModel.inTuneTolerance == 3)

        viewModel.a4Frequency = .infinity
        viewModel.inTuneTolerance = 100

        #expect(viewModel.a4Frequency == 440)
        #expect(viewModel.inTuneTolerance == 3)
    }
}
