import AVFoundation
import Foundation

/// A fake "singer" used by UI tests and demos without a microphone. It follows the melody with a small
/// deterministic wobble (+-10 cents), or holds A4 (440 Hz) when there is no melody (tuner).
final class SimulatedInput: AudioInput {
    var onReading: ((PitchReading) -> Void)?
    var onClassification: ((SingingState) -> Void)?
    var engine: AVAudioEngine? { nil }

    private let melody: Melody?
    private var timer: Timer?
    private var startDate = Date()

    init(melody: Melody?) { self.melody = melody }

    func start() throws {
        startDate = Date()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.023, repeats: true) { [weak self] _ in self?.tick() }
        onClassification?(SingingState(isSinging: true, label: "singing", confidence: 0.92))
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let time = Date().timeIntervalSince(startDate)
        let wobble = sin(time * 6) * 0.10   // +-10 cents
        var midi: Double?
        if let melody {
            if let target = melody.targetMidi(at: time) { midi = Double(target) + wobble }   // nil during rests
        } else {
            midi = 69 + wobble   // tuner: hold A4
        }
        onReading?(PitchReading(time: time, midi: midi, frequency: midi.map { Note.frequency(forMidi: $0) }))
        onClassification?(SingingState(isSinging: true, label: "singing", confidence: 0.92))
    }
}
