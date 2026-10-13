# SwaraCoach — Project Report
SE4041 Mobile Application Design & Development · Assignment 02, Part A
Student: *(name, ID)* · Date: 16 October 2026

> Items in **[brackets]** are measurements or observations to fill in from the lab session. Everything else describes what was built.

## 1. Introduction
**Problem.** Many people enjoy singing — in school choirs, at church, at karaoke — but cannot tell whether they are in tune. Lessons are expensive and not available everywhere; ordinary karaoke apps show lyrics but not *where* a voice drifts.
**Purpose.** SwaraCoach helps amateur singers in Sri Lanka improve their pitch without a teacher. It listens on the device, shows the singer's pitch live against the target melody, scores accuracy fairly by recognising when the user is actually singing, and tracks progress over time.
**Objectives.** (1) real-time pitch detection and visualisation; (2) fair scoring using on-device machine learning; (3) tuner and voice-range test; (4) persistent progress history; (5) accessible, polished SwiftUI interface; (6) tested and documented.

## 2. Target audience
Three personas: **Tharushi, 16**, school choir member preparing for a competition with no private teacher (needs to know which notes are off, practises daily → live graph, per-song score, streak); **Dilan, 24**, office worker and karaoke fan with limited time (quick sessions, stars, visible progress); **Ms. Fernando, 45**, music teacher with 30 students (objective cents-based scoring, exercises by difficulty). Smartphones are already in these users' hands and a phone microphone is good enough for pitch detection. Teenagers and young adults expect game-like feedback (stars, streaks); teachers need accuracy and simplicity (cents, clean layout). **[Survey: 10–15 people — how they practise singing, whether they know when they are off-key; add 3 findings.]**

## 3. Related apps
**[Try 2–3 apps (e.g. a karaoke app, a vocal-training app, a tuner app) and fill in: what they do / what SwaraCoach does differently.]** Differences to emphasise: live pitch-versus-melody graph, ML-gated fair scoring, swara (Sa Re Ga Ma) exercises, fully on-device and offline, no copyrighted backing tracks (guide tone is synthesised).

## 4. Design
Dark-first "stage" look for the sing screen (high contrast for the pitch line) and standard light/dark elsewhere. Brand colour purple `#6A3FD8` (tint `#B79CFF` in dark mode); green/amber/red for in-tune/close/off, always paired with text. System text styles and `@ScaledMetric` for Dynamic Type; spacing 4/8/12/16/24; cards with 16 pt continuous corners and a subtle glow in Dark Mode. App icon: a sound wave turning into a rising pitch line on a purple gradient. **[Insert mockups (from the build guide) next to final screenshots.]**
Navigation: `TabView` with three `NavigationStack`s; the sing session is a full-screen cover so nothing distracts the singer.
Accessibility: VoiceOver labels on the graph, gauge, score ring and stars; Reduce Motion replaces springs and counters; haptic feedback; feedback is never colour-only or sound-only. **[Screenshots: Dark Mode, AX5 text size, iPad.]**

## 5. Architecture
MVVM with a service layer (see `TechnicalDocs.md` §2 for the audio pipeline diagram). Pure logic in `Core/` is unit-tested; audio hardware sits behind the `AudioInput` protocol so a `SimulatedInput` can drive UI tests. Audio runs on a dedicated queue; view models are `@MainActor @Observable`. SwiftData stores session summaries and the voice profile.

## 6. Implementation
- **Pitch detection (YIN):** compares the signal with delayed copies of itself. For each delay, the squared difference is summed (with Accelerate `vDSP_vsub` and `vDSP_svesq`), normalised, and the first delay with a small value is taken as the period; parabolic interpolation refines it. [Code excerpt: `PitchDetector.detect`.]
- **Buffering:** a fixed 2048-sample window with 1024-sample hop, independent of the buffer sizes iOS delivers.
- **Smoothing:** median of 5, ignoring one-frame octave jumps.
- **Scoring:** octave-tolerant cents error, 0.15 s reaction window, score = 80 % in-tune + 20 % coverage, stars at 40/65/85.
- **Graph:** `TimelineView(.animation)` + `Canvas`, scrolling target bars against a fixed playhead.
- **Guide melody:** `AVAudioSourceNode` sine synth driven by a clock loop (no drift).
- **Custom components:** `PitchGraphView`, `TunerGaugeView`, `ScoreRingView`, `StarRatingView`, `.glowCard()` modifier, `Theme`.

## 7. Emerging technology: on-device sound classification
SwaraCoach uses **SoundAnalysis** (`SNClassifySoundRequest`, Apple's built-in Core ML sound classifier) to decide whether the user is singing. The labels that mean singing are discovered at runtime from the model's `knownClassifications`; if the confidence of any of them exceeds 0.35 the pitch samples in that moment are scored, otherwise they are ignored and a hint explains why ("We hear talking — try singing 'aah'"). This is meaningful because it directly fixes a real problem of pitch-based scoring: talking, noise and music otherwise produce random pitches that corrupt the score. The classifier also powers the "Singing detected · 92 %" chip on the Tuner.
**Evaluation:** **[Insert the table and accuracy from `ClassifierEvaluation.md`; discuss errors and the threshold choice.]**
**Limitations:** about one second of latency, accuracy depends on the room, tested on one phone, speaker bleed from the guide tone.

## 8. Testing
**Unit tests** (XCTest, 40+ cases): detector on sine waves from 110–880 Hz at 44.1 and 48 kHz within 1 %, silence and quiet-noise rejection, harmonic-rich tone, smoother behaviour, note maths, melody validity (no overlaps, singable range), scoring (perfect → 3 stars, 30 cents flat still in tune, 300 cents off → 0 stars, non-singing ignored, late singer forgiven), voice types, streaks, SwiftData in memory, range-test logic. **[Result: X of Y passed; coverage Z %.]**
**UI tests** (XCUITest): tab navigation, tuner shows the simulated A4, full sing flow with a simulated singer to results and history, swipe to delete, launch metric. A `-uiTesting` flag swaps the microphone for `SimulatedInput` and uses an in-memory store. **[Result.]**
**Algorithm cross-check:** because Swift could not be compiled while writing, the YIN detector and the scoring maths were re-implemented in Python and run on the same test inputs before the lab (all detected frequencies within 0.02 %).
**UAT:** **[Summarise `UAT.md`: participants, tasks, success rates, ratings, changes made.]**

## 9. Performance
- YIN's inner loop uses vDSP instead of Swift loops. **[Time Profiler screenshot; optional: measured time per window from `testPerformanceOfOneWindow` — report the number.]**
- Audio analysis runs off the main thread; the main thread receives ~43 small updates per second. **[Instruments screenshot showing the main thread idle.]**
- Memory: only summaries are persisted; samples for a 2-minute song are ≈ 5 000 small structs. **[Allocations screenshot.]**
- Latency trade-off: a 2048-sample window (≈ 46 ms) is the smallest that still resolves 70 Hz (needs ≥ 2 periods = 29 ms). Smaller = faster but poorer for low voices.
- Energy: engine and analyser are stopped when leaving the session or tuner. **[Launch time from the UI test metric.]**

## 10. Challenges
Speaker bleed of the guide tone into the microphone (headphones advised, onboarding page); octave errors and jitter in pitch detection (median filter + octave-tolerant scoring); iOS not honouring the requested buffer size (window buffering); timing drift of the guide melody (clock-based loop instead of per-note sleeps); no Mac at hand (generated Xcode project, GitHub Actions compile, a single lab session); **[add real bugs found at the lab]**.

## 11. Reflection
**[What went well, what you would change, what you learned about audio programming and about planning with limited Mac access.]** Future work: transposing songs to the user's range, listen-back recording, custom Create ML model for singing quality, duet mode, teacher dashboard, Sinhala localisation.

## 12. AI usage
Claude (Anthropic) was used for planning, code generation, tests and documentation; all of it is logged in `AI_LOG.md`. The code was reviewed, built, tested and tuned by the author, who can explain every file (`VIVA_WALKTHROUGH.md`).

## References
- A. de Cheveigné and H. Kawahara, "YIN, a fundamental frequency estimator for speech and music," *J. Acoust. Soc. Am.* 111(4), 2002.
- Apple Developer Documentation: AVFoundation (AVAudioEngine), Accelerate (vDSP), SoundAnalysis, SwiftData, Swift Charts, SwiftUI.
