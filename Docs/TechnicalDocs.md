# SwaraCoach — Technical Documentation

## 1. Overview
SwaraCoach is a SwiftUI iOS app (iOS 17+) using MVVM. Pure logic lives in `Core/` so it can be unit tested without a device; audio hardware is hidden behind the `AudioInput` protocol so tests and UI tests can use a simulated singer.

## 2. Architecture
```
Microphone → AVAudioEngine tap ──copy──► serial analysis queue ──► PitchDetector (YIN/vDSP) → PitchSmoother
                 │                                                          │
                 └─copy of buffer──► SNAudioStreamAnalyzer (SoundAnalysis)   │
                                              │                              ▼
                                      SingingState (isSinging)       PitchReading(time, midi)
                                              └────────────┬─────────────────┘      (delivered on main queue)
                                                           ▼
                                  SessionViewModel / TunerViewModel / RangeTestViewModel (@MainActor, @Observable)
                                                           ▼
                                      Views: PitchGraphView (Canvas), readouts, results
                                                           ▼
                                      ScoreCalculator → ScoreResult → SwiftData (PracticeSession)
```
**Threading.** The audio tap runs on a real-time thread and only copies samples. All maths runs on one serial queue (`swaracoach.analysis`); SoundAnalysis runs on its own queue. Results hop to the main queue as small value types (about 43 per second at 44.1 kHz). Raw samples are kept in a `SampleStore` that is *not* observed, because the graph reads them every frame anyway.
**Why a window buffer.** `installTap(bufferSize:)` is only a request, so the app appends samples to `pending` and analyses a fixed 2048-sample window every 1024 samples (50 % overlap). Window size therefore does not depend on what iOS delivers. 2048 samples ≈ 46 ms at 44.1 kHz; the lowest detectable pitch is 70 Hz (needs 2 periods = 29 ms).

## 3. Types and responsibilities
| Type | File | Responsibility |
|---|---|---|
| `Note` | Core/Note.swift | Hz ↔ MIDI ↔ note name ↔ cents |
| `Melody`, `MelodyNote`, `MelodyLibrary` | Core/Melody*.swift | Song/exercise data in beats; target note at a time; built-in melodies |
| `PitchDetector` | Core/PitchDetector.swift | YIN pitch detection with vDSP |
| `PitchSmoother` | Core/PitchSmoother.swift | Median filter, rejects one-frame octave jumps |
| `ScoreCalculator`, `ScoreResult`, `PitchSample` | Core/Scoring.swift | Octave-tolerant cents error, score, stars |
| `VoiceType`, `StreakCalculator` | Core/VoiceRange.swift | Voice classification from range; practice streak |
| `AudioInput` (protocol), `PitchReading`, `SingingState`, `MicPermission`, `AppEnvironment` | Audio/AudioInput.swift | Abstraction over real and simulated audio; permission; `-uiTesting` switch |
| `MicrophoneInput` | Audio/MicrophoneInput.swift | AVAudioEngine tap, window buffering, detection pipeline |
| `SingingClassifier` | Audio/SingingClassifier.swift | SoundAnalysis built-in classifier → singing / not singing |
| `GuideSynth` | Audio/GuideSynth.swift | Sine-wave guide tone via `AVAudioSourceNode` |
| `SimulatedInput` | Audio/SimulatedInput.swift | Fake singer for UI tests and demos |
| `PracticeSession`, `VoiceProfile`, `Persistence` | Models/ | SwiftData models and container factory |
| `SessionViewModel` | ViewModels/ | One singing session: start audio, clock loop, collect samples, score, save |
| `TunerViewModel`, `RangeTestViewModel` | ViewModels/ | Tuner readout; range test hold logic |
| Views | Views/ | Screens (see README) |
| `PitchGraphView`, `TunerGaugeView`, `ScoreRingView`, `StarRatingView`, `GlowCard`, `Theme` | Components/ | Custom components, modifier, theming |

## 4. Algorithms
**YIN** (de Cheveigné & Kawahara 2002) in `PitchDetector`:
1. Difference function `d(τ) = Σ (x[i] − x[i+τ])²` for every lag τ between `sampleRate/1100` and `sampleRate/70`. Each lag is two vDSP calls (`vDSP_vsub`, `vDSP_svesq`).
2. Cumulative mean normalised difference `d'(τ) = d(τ)·τ / Σ d(j)`; removes the bias that makes small lags look good.
3. First τ where `d'` < 0.15, then walk down to the local minimum.
4. Parabolic interpolation around the minimum for sub-sample accuracy; `f = sampleRate / τ`.
A silence gate (RMS < 0.01) returns nil. Verified by unit tests on sine waves (110–880 Hz within 1 %).

**Scoring** (`ScoreCalculator`). For each sample where the classifier says *singing* and a pitch exists: error = min over the target note now and 0.15 s ago (reaction window) of the octave-folded cents difference. `inTune` = share of errors ≤ 50 cents; `coverage` = in-tune samples ÷ samples a perfect take would have; `score = 100·(0.8·inTune + 0.2·coverage)`; stars at 40/65/85.

**Octave folding.** `diff = (sung − target) mod 12`, then wrapped to ±6 semitones, so singing the melody an octave lower still scores as in tune.

**Guide timing.** `SessionViewModel.runLoop` polls the clock every 15 ms and sounds the note belonging to `elapsed`. Because it always reads the clock, errors do not accumulate (unlike scheduling each note with a separate sleep).

## 5. Data model (SwiftData)
`PracticeSession(songID, songTitle, date, score, inTunePercent, averageCentsOff, durationSeconds, stars)` and `VoiceProfile(lowestMidi, highestMidi, voiceTypeName, testedDate)`. Only summaries are stored. Melodies are bundled code, not user data. Container is in-memory for UI tests (`-uiTesting`).

## 6. Navigation
`TabView` with three `NavigationStack`s (Sing, Tuner, Progress). Typed destinations: `Melody` → `SongDetailView`; `PracticeSession` → `SessionDetailView`; `ProgressRoute.rangeTest` → `RangeTestView`. A session is presented with `fullScreenCover(item:)`. Onboarding is a full-screen cover controlled by `@AppStorage("hasOnboarded")`.

## 7. Accessibility and theming
`Theme` holds brand colours; error colours are always paired with text ("+12 cents · sharp"). System text styles + `@ScaledMetric`; at accessibility sizes the graph is hidden and the readout is larger. VoiceOver labels on graph, gauge, ring, stars. `accessibilityReduceMotion` disables springs and counters. Haptic feedback with `sensoryFeedback`.

## 8. Testing
Unit tests (XCTest, `SwaraCoachTests/`): pitch detection on synthetic tones, smoothing, note maths, melody validity, scoring and stars, voice types, streaks, SwiftData in memory, range-test logic. UI tests (`SwaraCoachUITests/`): tab navigation, tuner with simulated input, full sing flow to results and history, swipe to delete, launch performance. Run with Cmd+U.

## 9. Known limitations / future work
- Pitch detection is monophonic and phone-microphone dependent; thresholds (`threshold`, `silenceRMS`) were tuned on one phone.
- Classifier latency is about 1 second, so the first moments of a note may be gated.
- Guide tone through a speaker leaks into the microphone → headphones recommended.
- Not implemented (time): transposing songs to the user's range, listen-back recording, networking song packs, Sinhala localisation, duet mode, MIDI import.

## Importing your own song

`My Songs` (Sing tab) lets the user pick an audio file and practise its melody.

- `AudioFileAnalyzer` decodes up to the first 90 s with `AVAudioFile`, mixes to mono and lowers the sample rate to about 22 kHz.
- `MelodyExtractor` runs the same YIN `PitchDetector` over 2048-sample frames (hop 512), smooths with `PitchSmoother`, groups frames of similar pitch into notes (within 0.75 semitone of the running average, dropouts up to 80 ms tolerated), drops notes under 120 ms and joins same-pitch notes split by a short gap.
- `ImportedSong` (SwiftData) stores only the notes as JSON, never the audio. One beat is one second (60 bpm), so the notes keep their real timing. It exposes a normal `Melody`, so guide tones, the pitch graph, scoring and history work unchanged.
- Limit: YIN follows one pitch at a time, so a full band recording gives a messy melody. A solo voice, humming or a single instrument works best. The UI says this.
- Tests: `MelodyExtractorTests` (synthetic sine notes, silence, short blips, dropouts, difficulty, SwiftData round trip). Not yet tried on real songs.
