import Foundation
import Observation
import SwiftData

/// Two-step voice range test: hold your lowest comfortable note, then your highest, for 2 seconds each.
@MainActor
@Observable
final class RangeTestViewModel {
    enum Step: Equatable { case low, high, done }

    private(set) var step: Step = .low
    private(set) var lowestMidi: Int?
    private(set) var highestMidi: Int?
    private(set) var currentName = "–"
    private(set) var holdProgress = 0.0     // 0...1 while holding a steady note
    private(set) var errorMessage: String?
    private(set) var isRunning = false

    static let holdSeconds = 2.0
    static let toleranceSemitones = 0.3     // +-30 cents counts as "steady"

    @ObservationIgnored private var input: AudioInput?
    @ObservationIgnored private var anchor: Double?
    @ObservationIgnored private var anchorTime = 0.0

    var voiceType: VoiceType? {
        guard let low = lowestMidi, let high = highestMidi else { return nil }
        return VoiceType.classify(lowest: low, highest: high)
    }

    func start() async {
        guard !isRunning else { return }
        if !AppEnvironment.isUITesting {
            let granted = MicPermission.isGranted ? true : await MicPermission.request()
            guard granted else { errorMessage = "Microphone access is off. Turn it on in Settings."; return }
        }
        let input = AppEnvironment.makeInput(for: nil)
        input.onReading = { [weak self] reading in self?.handle(reading) }
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
    }

    func restart() {
        lowestMidi = nil
        highestMidi = nil
        step = .low
        resetHold()
    }

    /// Public so unit tests can feed readings without audio.
    func handle(_ reading: PitchReading) {
        guard step != .done else { return }
        guard let midi = reading.midi else { resetHold(); return }
        currentName = Note(midi: midi).name
        if let anchor, abs(midi - anchor) <= Self.toleranceSemitones {
            holdProgress = min(1, (reading.time - anchorTime) / Self.holdSeconds)
            if reading.time - anchorTime >= Self.holdSeconds { accept(Int(anchor.rounded())) }
        } else {
            anchor = midi
            anchorTime = reading.time
            holdProgress = 0
        }
    }

    private func accept(_ midi: Int) {
        switch step {
        case .low:
            lowestMidi = midi
            step = .high
        case .high:
            // The high note must be above the low one; otherwise keep waiting.
            guard let low = lowestMidi, midi > low else { resetHold(); return }
            highestMidi = midi
            step = .done
            stop()
        case .done:
            break
        }
        resetHold()
    }

    private func resetHold() {
        anchor = nil
        holdProgress = 0
    }

    func save(in context: ModelContext) {
        guard let low = lowestMidi, let high = highestMidi else { return }
        if let existing = try? context.fetch(FetchDescriptor<VoiceProfile>()) {
            existing.forEach { context.delete($0) }
        }
        context.insert(VoiceProfile(lowestMidi: low, highestMidi: high))
        try? context.save()
    }
}
