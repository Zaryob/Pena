# Local tuner validation

9 October 2026 (Europe/Istanbul); macOS 27.0 (26A428), Apple M4, 16 GiB RAM, Xcode 27.0 (27A266a), Apple Clang 21.0.0. Runs shared a busy development host; timings are observations, not performance guarantees.

Source baseline: [`5b4115417b05d8dcc318c6ea2303c0d402aeb9e6`](https://github.com/Zaryob/Pena/commit/5b4115417b05d8dcc318c6ea2303c0d402aeb9e6). Production code and tests were unchanged; this change records existing synthetic coverage and corrects the README destination instructions.

Executed on an iPhone 18 Pro simulator with iOS 27.0:

```sh
xcodebuild -project Pena.xcodeproj -scheme Pena -showdestinations
xcodebuild -project Pena.xcodeproj -scheme Pena \
  -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_UDID' \
  -derivedDataPath build/validation CODE_SIGNING_ALLOWED=NO test
```

Xcode reported **39 test definitions passed**, zero failures/skips; the per-device execution count was **93** including parameterized cases. The test command above produces a local result bundle; exported test reports are not tracked in the repository. Synthetic cases exercise supported tuning presets, harmonic/noisy/detuned signals, octave handling, A4 changes and invalid configurations. Counts describe this run, not a CI badge or a universal tuning-accuracy claim.

Not verified: microphone permissions/input on physical hardware, acoustic accuracy across instruments/noise levels, audio-session interruptions, route changes, latency, battery cost, signed distribution or a beta binary. No GitHub Release was published at the audit snapshot. The physical audio and beta acceptance work remains in [#2](https://github.com/Zaryob/Pena/issues/2).
