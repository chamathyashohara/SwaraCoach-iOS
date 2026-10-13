import Foundation

/// Converts between frequency (Hz), MIDI note numbers, note names and cents.
/// MIDI 69 is A4 = 440 Hz; one semitone is 100 cents.
struct Note: Equatable {
    static let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    /// Fractional MIDI number (e.g. 69.25 is A4 sharp by 25 cents).
    let midi: Double

    init(frequency: Double) { midi = 69 + 12 * log2(frequency / 440) }
    init(midi: Double) { self.midi = midi }

    /// Nearest whole MIDI note.
    var nearest: Int { Int(midi.rounded()) }
    /// Distance from the nearest note in cents, always in -50...+50.
    var cents: Double { (midi - Double(nearest)) * 100 }
    var name: String { Note.name(forMidi: nearest) }
    var frequency: Double { Note.frequency(forMidi: midi) }

    static func frequency(forMidi midi: Double) -> Double { 440 * pow(2, (midi - 69) / 12) }

    /// Name such as "C4". Uses floor division so negative values stay correct.
    static func name(forMidi midi: Int) -> String {
        let index = ((midi % 12) + 12) % 12
        let octave = Int((Double(midi) / 12).rounded(.down)) - 1
        return "\(names[index])\(octave)"
    }
}
