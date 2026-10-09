<div align="center">

# 🎸 Pena

**Tune, play, and learn your guitar.**

![Platform](https://img.shields.io/badge/platform-iOS-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-SwiftUI-orange?logo=swift)
![iOS](https://img.shields.io/badge/iOS-27.0%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)

<br>

<img src="audit/pena-ui/01-main-screen.png" alt="Pena tuner screen" width="280">

</div>

---

[Features](#-features) · [Screenshots](#-screenshots) · [Architecture](#-architecture) · [Getting started](#-getting-started) · [Localization](#-localization) · [Design language](#-design-language) · [License](#-license)

Pena is an iOS tuning and learning companion for guitarists, combining real-time pitch detection, a haptic metronome, an interactive chord library, and style-based 30-day curricula in a single SwiftUI app.

### ✨ Features

#### 🎵 Tuner
| | |
|---|---|
| **Real-time pitch detection** | `AVAudioEngine`-based low-latency microphone input and a custom pitch detection algorithm. |
| **Analog gauge + headstock view** | A gauge meter and an animated headstock visualization for instant, intuitive feedback. |
| **6 tuning presets** | Standard, Drop D, Half Step Down (E♭), DADGAD, Open D, Open G. |
| **Auto / Manual mode** | Automatically track the detected string, or pick a string manually. |
| **Reference tone & accuracy** | Reference tone playback, cents readout, color/haptic feedback based on tuning status. |

#### 📚 Academy
| | |
|---|---|
| **10 styles × 30 days** | Blues, Bossa Nova, Jazz, Country, Fingerstyle, Flamenco, Funk, Classical, Rock, Turkish Folk. |
| **Daily plan detail** | Each plan ships with daily practice goals, required materials, prerequisites and an end-of-month target. |
| **Fretboard roadmap** | Step-by-step progress through day-by-day lesson detail screens. |
| **Persistent progress** | Progress is stored on-device via `CourseProgressStore`. |

#### 🛠️ Tools
| | |
|---|---|
| **Haptic metronome** | Adjustable tempo with tactile feedback. |
| **Interactive chord library** | Explore chords and fold them into practice sessions. |

### 📸 Screenshots

<table>
  <tr>
    <td width="33%"><img src="audit/pena-ui/01-main-screen.png" alt="Tuner screen"></td>
    <td width="33%"><img src="audit/pena-ui/02-runtime-main.png" alt="App running"></td>
    <td width="33%"><img src="audit/pena-ui/03-settings.png" alt="Settings"></td>
  </tr>
  <tr>
    <td align="center"><b>Tuner</b> — gauge + headstock</td>
    <td align="center"><b>Runtime</b> — live tuning detection</td>
    <td align="center"><b>Settings</b> — A4 calibration, tolerance</td>
  </tr>
</table>

### 🧱 Architecture

Pena is built entirely with **SwiftUI** and Swift's modern `async/await` concurrency model (no Combine).

```
Pena/
├── AudioEngineManager.swift      # AVAudioEngine setup, mic permissions, session management
├── Audio/
│   ├── PitchDetector.swift       # Pitch (frequency) detection algorithm
│   └── PitchStabilizer.swift     # Smoothing/stabilizing the detected pitch
├── GuitarModel.swift             # String, tuning preset, tuning status, and music theory helpers
├── TunerViewModel.swift          # Tuner screen state management
├── TunerMainView.swift           # Tuner tab UI
├── GaugeMeterView.swift          # Analog gauge meter
├── HeadstockView.swift           # Guitar headstock visualization
├── SettingsSheetView.swift       # Settings (A4 calibration, tolerance, etc.)
├── Courses/
│   ├── CourseModel.swift         # Course/lesson data models (flexible JSON decoding)
│   ├── ChordDatabase.swift       # Chord database
│   ├── CourseProgressStore.swift # Progress persistence
│   └── Resources/*.json          # 30-day curriculum data for each of the 10 styles
└── Views/
    ├── Academy/                  # Catalog, roadmap, day detail, practice session
    └── Tools/                    # Metronome and chord library UI
```

**Data flow.** `AudioEngineManager` feeds microphone input into `PitchDetector`; the raw detected frequency is smoothed by `PitchStabilizer` and forwarded to `TunerViewModel`. The view model computes the cents offset (`MusicPitchHelper`) against the nearest string in the active `TuningPreset`, and reflects it as a `TuningStatus` (in-tune / flat / sharp) in `TunerMainView`.

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| State | Observation (`@Observable`), `async/await` |
| Audio | `AVAudioEngine`, custom pitch detection |
| Persistence | `UserDefaults` / file-based (`CourseProgressStore`) |
| Data | Static JSON curricula (`Courses/Resources`) |
| Accessibility | Dynamic Type, VoiceOver |

The app has three main tabs (`ContentView.swift`): **Tuner**, **Academy**, **Tools**.

### 🚀 Getting Started

#### Requirements

| | Minimum |
|---|---|
| iOS / iPadOS | 27.0 |
| Xcode | iOS 27 SDK |
| Microphone access | A physical device is recommended for real pitch detection |

#### Run
```bash
open Pena.xcodeproj
```
Select the `Pena` scheme in Xcode and run (⌘R).

#### Tests
```bash
xcodebuild -project Pena.xcodeproj -scheme Pena -showdestinations
# Use the id of an available iOS 27 simulator from the command above:
xcodebuild test -project Pena.xcodeproj -scheme Pena -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_UDID' CODE_SIGNING_ALLOWED=NO
```
The test suite lives under `PenaTests/` and covers pitch detection, pitch stabilization, string matching, and course models.

[Local validation](docs/VALIDATION.md) records the tested simulator, SDK and actual test counts. The deterministic harmonic/noise tests do not establish physical microphone accuracy or end-to-end detection latency.

#### Distribution status

No public binary release was present on 9 October 2026. Build from source above. A signed beta still requires physical-device microphone, permission-denial, audio-interruption and installation checks.

### 🌍 Localization

UI strings are managed via `Localizable.xcstrings`; the default language is Turkish. Use Xcode's String Catalog support to add new languages.

### 🎨 Design Language

A dark theme accented with **"Pena Signature Gold"**, designed to be clean and distraction-free. Built with Dynamic Type and VoiceOver support in mind — see `audit/pena-ui/04-dynamic-type-ax3.png`.

### 📄 License

This project is licensed under the [MIT License](LICENSE).
