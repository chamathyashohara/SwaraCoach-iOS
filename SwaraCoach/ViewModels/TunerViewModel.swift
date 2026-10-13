import Foundation
import Observation

/// Free tuner: shows the note, frequency and cents of whatever the user sings or plays.
@MainActor
@Observable
final class TunerViewModel {
    private(set) var noteName = "–"
    private(set) var frequency = 0.0
    private(set) var cents = 0.0
    private(set) var hasPitch = false
    private(set) var singingState = SingingState.idle
    private(set) var isRunning = false
    private(set) var errorMessage: String?

    @ObservationIgnored private var input: AudioInput?
    @ObservationIgnored private var silentFrames = 0

    var isInTune: Bool { hasPitch && abs(cents) <= 10 }

    func start() async {
        guard !isRunning else { return }
        errorMessage = nil
        if !AppEnvironment.isUITesting {
            let granted = MicPermission.isGranted ? true : await MicPermission.request()
            guard granted else {
                errorMessage = "Microphone access is off. Turn it on in Settings > SwaraCoach."
                return
            }
        }
        let input = AppEnvironment.makeInput(for: nil)
        input.onReading = { [weak self] reading in self?.handle(reading) }
        input.onClassification = { [weak self] state in self?.singingState = state }
        do {
            try input.start()
            self.input = input
            isRunning = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        input?.stop()
        input = nil
        isRunning = false
        hasPitch = false
    }

    private func handle(_ reading: PitchReading) {
        if let midi = reading.midi, let frequency = reading.frequency {
            let note = Note(midi: midi)
            noteName = note.name
            cents = note.cents
            self.frequency = frequency
            hasPitch = true
            silentFrames = 0
        } else {
            silentFrames += 1
            if silentFrames > 8 { hasPitch = false }   // keep the last note on screen briefly to avoid flicker
        }
    }
}
