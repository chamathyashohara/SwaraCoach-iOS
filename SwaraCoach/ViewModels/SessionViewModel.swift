import Foundation
import Observation
import SwiftData

/// Keeps the raw pitch samples outside of the observation system. The graph reads them every frame,
/// so we do not want SwiftUI to re-evaluate view bodies each time a sample is appended.
final class SampleStore {
    var samples: [PitchSample] = []
}

/// Runs one singing session: starts the audio input and guide melody, collects samples, scores at the end.
@MainActor
@Observable
final class SessionViewModel {
    enum Phase: Equatable { case ready, running, finished, failed(String) }

    let melody: Melody
    private(set) var phase: Phase = .ready
    private(set) var startDate = Date()

    // Live readout
    private(set) var noteName = "–"
    private(set) var cents = 0.0
    private(set) var hasPitch = false
    private(set) var progress = 0.0
    private(set) var singingState = SingingState.idle
    private(set) var currentSyllable: String?

    // Result
    private(set) var result: ScoreResult = .empty
    private(set) var previousBest: Int?

    @ObservationIgnored let store = SampleStore()
    @ObservationIgnored private var input: AudioInput?
    @ObservationIgnored private var synth: GuideSynth?
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var classifierSeen = false

    init(melody: Melody) { self.melody = melody }

    /// Hint shown under the graph while singing.
    var hint: String? {
        guard phase == .running, classifierSeen, hasPitch == false || singingState.isSinging == false else { return nil }
        if singingState.label.lowercased().contains("speech") { return "We hear talking. Try singing “aah”." }
        if singingState.label.lowercased().contains("music") { return "Music detected. Use headphones for the guide tone." }
        return nil
    }

    func begin() async {
        guard phase == .ready else { return }
        if !AppEnvironment.isUITesting {
            let granted = MicPermission.isGranted ? true : await MicPermission.request()
            guard granted else {
                phase = .failed("Microphone access is off. Turn it on in Settings > SwaraCoach to sing.")
                return
            }
        }
        let input = AppEnvironment.makeInput(for: melody)
        input.onReading = { [weak self] reading in self?.handle(reading) }
        input.onClassification = { [weak self] state in
            self?.classifierSeen = true
            self?.singingState = state
        }
        if let engine = input.engine { synth = GuideSynth(engine: engine) }   // attach before the engine starts
        do {
            try input.start()
        } catch {
            phase = .failed(error.localizedDescription)
            return
        }
        self.input = input
        store.samples.removeAll()
        startDate = Date()
        phase = .running
        runLoop()
    }

    /// Clock-based loop: sounds the guide note that belongs to the current time and detects the end.
    /// Using the clock (not one timer per note) means timing cannot drift.
    private func runLoop() {
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let elapsed = Date().timeIntervalSince(self.startDate)
                self.progress = min(1, elapsed / self.melody.duration)
                let target = self.melody.note(at: elapsed)
                self.synth?.play(midi: target?.midi)
                self.currentSyllable = target?.syllable
                if elapsed >= self.melody.duration + 0.3 {
                    self.finish()
                    return
                }
                try? await Task.sleep(for: .milliseconds(15))
            }
        }
    }

    private func handle(_ reading: PitchReading) {
        guard phase == .running else { return }
        let singing = classifierSeen ? singingState.isSinging : true
        store.samples.append(PitchSample(time: reading.time, midi: reading.midi, isSinging: singing))
        if let midi = reading.midi {
            let note = Note(midi: midi)
            noteName = note.name
            cents = note.cents
            hasPitch = true
        } else {
            hasPitch = false
        }
    }

    func finish() {
        guard phase == .running else { return }
        stopAudio()
        result = ScoreCalculator.score(samples: store.samples, melody: melody)
        phase = .finished
    }

    func cancel() {
        stopAudio()
        if phase == .running { phase = .ready }
    }

    func reset() {
        stopAudio()
        store.samples.removeAll()
        progress = 0
        hasPitch = false
        noteName = "–"
        result = .empty
        phase = .ready
    }

    private func stopAudio() {
        loop?.cancel()
        loop = nil
        synth?.silence()
        input?.stop()
        input = nil
        synth = nil
    }

    /// Saves the finished attempt and works out whether it beat the previous best for this song.
    func save(in context: ModelContext) {
        let songID = melody.id
        let descriptor = FetchDescriptor<PracticeSession>(predicate: #Predicate { $0.songID == songID })
        let earlier = (try? context.fetch(descriptor)) ?? []
        previousBest = earlier.map(\.score).max()
        context.insert(PracticeSession(songID: melody.id, songTitle: melody.title, result: result, duration: melody.duration))
        try? context.save()
    }
}
