# Thursday lab session — one session, both apps

**You have one lab session (Thursday 1 pm) and the deadline is Friday 16 Oct.** Everything below is ordered so that, if time runs out, the most valuable things are already done. Bring: iPhone + USB cable, wired headphones, this checklist on your phone/laptop, a USB stick with a copy of the repos (backup).

## Before the lab (Wednesday, on Windows) — about 30 minutes
1. Create two **private** GitHub repos: `SwaraCoach-iOS` and `SoundSpace-visionOS`, attach them to the Claude project (Project settings → repositories). I push all code to them.
2. When I tell you the code is pushed, open the repo on github.com → **Actions** tab. The "Build and test" workflow compiles both apps on GitHub's Macs. If it is red, paste me the log; I fix it **before** you reach the lab. When it is green it also commits the generated `.xcodeproj` into the repo, so at the lab you only need `git clone`.
3. Find 3–5 friends who can try the app for 5 minutes at/after the lab (UAT). Print or open `Docs/UAT.md`.
4. Optional: install GitHub Desktop or have `git` ready on the lab Mac (Xcode includes git).

## At the lab — in this order

### 0. Sanity checks (5 min)
- Apple menu → About This Mac: **Apple silicon (M1/M2/M3)?** Note Xcode version: Xcode → About Xcode.
- Xcode → Settings → Components (or Platforms): is **iOS** and **visionOS** simulator installed? If visionOS is missing, ask lab staff now (needs admin) and do Part A first.
- Disk: files may be wiped on logout, so push to GitHub before you leave.

### 1. Get the code (5 min)
```
git clone https://github.com/<your-user>/SwaraCoach-iOS.git
git clone https://github.com/<your-user>/SoundSpace-visionOS.git
```
Open `SwaraCoach-iOS/SwaraCoach.xcodeproj` in Xcode. (If the `.xcodeproj` is missing because CI never ran, follow **Appendix A** to create the project by hand.)

### 2. SwaraCoach: build and fix (20–30 min)
1. Select an iPhone simulator, press **Cmd+B**.
2. Copy compile errors to me (Product → Show Build Issues, or paste the red text). I fix quickly; apply, rebuild. Expect a few.
3. **Cmd+U** to run the unit and UI tests. Screenshot the passing test list (evidence). Failing test = tell me which.
4. **Cmd+R** the app. Walk through onboarding → tuner (talk, then hum; the chip should change) → sing a song with headphones.

### 3. SwaraCoach on your iPhone (15 min, most important for the demo)
1. Plug in iPhone; on iPhone: Settings → Privacy & Security → **Developer Mode** on (restarts the phone).
2. In Xcode: target SwaraCoach → Signing & Capabilities → Team: your Apple ID (Add Account if needed) → change bundle ID to something unique e.g. `lk.<yourname>.swaracoach`.
3. Choose your iPhone as run destination, Cmd+R; on iPhone trust the developer (Settings → General → VPN & Device Management).
4. Sing "Twinkle Twinkle" with headphones. Note: does the pitch line follow you? Does the classifier chip say singing? **Tell me the results** — I tune thresholds (`PitchDetector.threshold`, `SingingClassifier.threshold`) and you rebuild.

### 4. Classifier evidence (10 min, 15 marks of rubric depend on this)
In Tuner, record the chip for 5 situations × 4 tries: singing "aah", humming, talking, silence/room noise, music playing from a speaker. Fill the table in `Docs/ClassifierEvaluation.md` (I prepared it). Also screenshot the chip showing "Singing detected".

### 5. SoundSpace: build and run (30 min)
1. Open `SoundSpace-visionOS/SoundSpace.xcodeproj`, destination **Apple Vision Pro** simulator, Cmd+B, send me errors, fix, Cmd+R.
2. Control panel appears. Press **Enter studio**. In the simulator, **click = pinch**; use the toolbar/keyboard to look around (hold Option+drag moves the view).
3. Click each instrument (should play a sound and squash). Switch to **Arrange** mode and drag an instrument. **Record**: hit instruments for 5 seconds → loop replays. **Start lesson**.
4. Cmd+U for the SoundSpace unit tests.
5. If spatial audio is silent, tell me what you see in the Xcode console (sound load messages).

### 6. Evidence and demo recording (20 min)
- Screenshots (Cmd+S in simulator saves a PNG): SwaraCoach — onboarding, library, sing screen, results, tuner, progress, dark mode, large text (Settings → Accessibility → Larger Text in simulator or Xcode Environment Overrides), iPad (iPad simulator). SoundSpace — control panel, studio with all 4 instruments, loop recorder, lesson result.
- Screen recordings: QuickTime Player → File → New Screen Recording (or `xcrun simctl io booted recordVideo demo.mov`). Record: 1 min SwaraCoach on iPhone (screen recording from iPhone: Control Centre), 1 min SoundSpace in simulator.
- Performance (2 min): run once with Instruments → Time Profiler on SwaraCoach while singing (Product → Profile); screenshot the call tree showing audio work off the main thread. Optionally Xcode's debug gauges (CPU/Memory) screenshot while singing.

### 7. UAT (15 min, can be done after the lab on your iPhone)
Give the app to 3–5 people with the tasks in `Docs/UAT.md`; note times and comments.

### 8. Before leaving (10 min) — do not skip
- `git add -A && git commit -m "Lab session: fixes, screenshots, evidence" && git push` in both repos (screenshots go in `Docs/Screenshots/`).
- Copy the screenshots/videos to a USB stick or upload to Google Drive too.
- Sign out of GitHub / Apple ID on the lab Mac.

## Friday (Windows)
I assemble the final report from your screenshots + test numbers, you read it, export PDFs, submit. Keep two hours free for rehearsing the viva using `Docs/VIVA_WALKTHROUGH.md`.

## If time runs short — priority order
1. SwaraCoach builds, runs on iPhone, tests pass (screenshots).
2. Classifier table + screenshots.
3. SoundSpace builds and runs in the simulator (screenshots + 1 min recording).
4. Performance screenshots.
5. Everything else.

---
## Appendix A — create the iOS project by hand (only if the `.xcodeproj` is missing)
1. Xcode → File → New → Project → iOS → App. Product name **SwaraCoach**, Interface **SwiftUI**, Language **Swift**, Storage **SwiftData**, tick *Include Tests*. Save inside a temp folder.
2. Delete the template's `ContentView.swift`, `Item.swift`, `SwaraCoachApp.swift` and the template test files.
3. Drag the repo's `SwaraCoach/` folder contents (App, Core, Audio, Models, ViewModels, Views, Components, Resources) into the app target group ("Create groups", tick the app target). Drag `SwaraCoachTests/*.swift` into the unit-test target and `SwaraCoachUITests/*.swift` into the UI-test target (create a UI Testing Bundle target if missing).
4. Target → General → Minimum Deployments **iOS 17.0**. Build Settings → search "Swift Language Version" → **Swift 5**.
5. Target → Info → add `Privacy - Microphone Usage Description` = "SwaraCoach listens to your voice to show your pitch. Audio stays on your device."
6. Assets: set App Icons source to the `AppIcon` set from `Resources/Assets.xcassets`.
## Appendix B — create the visionOS project by hand
1. File → New → Project → **visionOS** → App. Name **SoundSpace**, Initial scene **Window**, Immersive Space Renderer **RealityKit**, Immersive Space **Mixed**. Add Tests.
2. Delete the template's content/immersive files and `SoundSpaceApp.swift`; drag in the repo's `SoundSpace/` folders (App, Core, Studio, Views, Resources/Sounds → tick "Copy items" off, "Add to target" on).
3. Build Settings → Swift Language Version **Swift 5**. Info → *Application Scene Manifest* → *Enable Multiple Scenes* = YES.
