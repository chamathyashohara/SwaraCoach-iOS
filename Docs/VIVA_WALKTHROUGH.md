# Viva walkthrough — SwaraCoach

Rehearse by opening each file while you read its summary. Be ready to change a small thing live (a colour in `Theme`, the in-tune tolerance in `ScoreCalculator.score`, the star thresholds, the median size in `PitchSmoother`).

## The 60-second story
"SwaraCoach helps amateur singers in Sri Lanka improve their pitch without a teacher. It listens through the microphone, detects the pitch with the YIN algorithm, draws it live against the melody, and scores how often you are in tune. Apple's on-device sound classifier makes the scoring fair by ignoring speech and noise. Results are saved with SwiftData and shown in charts."

## File by file
| File | Say this |
|---|---|
| `Core/Note.swift` | MIDI note numbers are semitones; `69 + 12·log2(f/440)`. Cents = distance to the nearest semitone ×100. |
| `Core/PitchDetector.swift` | YIN: compare the signal with delayed copies of itself; the first small difference is the period; frequency = rate/period. vDSP does the heavy sums. |
| `Core/PitchSmoother.swift` | Median of 5; one-frame jumps of about an octave are ignored. |
| `Core/Scoring.swift` | Octave folding with `truncatingRemainder` to ±6 semitones; score = 80 % in-tune + 20 % coverage; reaction window 0.15 s because singers react late. |
| `Core/Melody*.swift` | Songs are data in beats; `note(at:)` finds the target at a time. Notes last 90 % of their beat so repeated notes are separated. |
| `Audio/MicrophoneInput.swift` | Tap callback only copies; queue does maths; fixed 2048 window with 1024 hop; time axis from sample counts; delivers on main queue. |
| `Audio/SingingClassifier.swift` | `SNClassifySoundRequest(.version1)` is Apple's built-in Core ML model. We find the singing-related labels from `knownClassifications` and threshold at 0.35. Buffers are copied because the engine reuses them. |
| `Audio/GuideSynth.swift` | `AVAudioSourceNode` renders a sine wave; amplitude is smoothed to avoid clicks. No audio files = no copyright. |
| `ViewModels/SessionViewModel.swift` | State machine ready → running → finished; a clock loop plays the guide note and ends the song; samples live in an un-observed store. |
| `Components/PitchGraphView.swift` | `TimelineView(.animation)` + `Canvas`, redrawn every frame; x = time, y = pitch; only visible samples are drawn. |
| `Components/TunerGaugeView.swift` | Custom drawing with paths; needle rotation = cents × 0.9 (±50 cents → ±45°) with a spring animation. |
| `Components/GlowCard.swift` | Custom `ViewModifier` (+ `View` extension) used for cards. |
| `Models/PracticeSession.swift` | SwiftData `@Model`s; `Persistence.makeContainer(inMemory:)` for tests. |
| `Views/Progress/ProgressDashboardView.swift` | `@Query` sorted by date; streak and weekly average are computed; `MagnifyGesture` changes the visible days; `.onDelete`. |

## Likely questions
- **How does pitch detection work?** (YIN above.) **Why not FFT?** FFT peaks often hit a harmonic, not the fundamental; YIN works in time and finds the period.
- **Where is the ML?** SoundAnalysis built-in classifier (Core ML) decides singing vs not; only singing is scored. I measured accuracy myself (`Docs/ClassifierEvaluation.md`).
- **Why can I sing an octave lower?** Octave folding in `centsError`.
- **How did you keep the UI smooth?** Audio and analysis off the main thread; small updates only; graph reads an un-observed store; only visible samples drawn.
- **Why SwiftData?** Native to SwiftUI (`@Query`), built on Core Data, minimal code.
- **Why Swift 5 language mode?** Audio callbacks run on a real-time thread; Swift 6 strict concurrency would reject the callback captures without a larger redesign.
- **How did you test without a microphone?** Synthetic sine waves; `SimulatedInput`; in-memory store; `-uiTesting`.
- **Hardest bugs?** *(fill in from the lab: compile errors, thresholds, speaker bleed…)*
- **AI usage?** Be honest: Claude generated the first version from a plan I approved; I reviewed it, built/tested it on a Mac, tuned it on my iPhone and can explain each file. See `AI_LOG.md`.
