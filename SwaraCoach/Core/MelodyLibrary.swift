import Foundation

/// Built-in songs and exercises. All tunes are traditional / public domain; the exercises are generated.
/// Melodies are written in code (not a data file) so that they are checked by the compiler and unit tests.
enum MelodyLibrary {
    /// Builds a melody from consecutive (midi, beats) pairs. A nil pitch is a rest.
    private static func make(_ id: String, _ title: String, _ kind: Melody.Kind, _ difficulty: Melody.Difficulty,
                             bpm: Double, _ sequence: [(Int?, Double)], syllables: [String] = []) -> Melody {
        var beat = 0.0
        var notes: [MelodyNote] = []
        var syllableIndex = 0
        for (pitch, length) in sequence {
            if let pitch {
                let syllable = syllableIndex < syllables.count ? syllables[syllableIndex] : nil
                notes.append(MelodyNote(start: beat, length: length * 0.9, midi: pitch, syllable: syllable))
                syllableIndex += 1
            }
            beat += length
        }
        return Melody(id: id, title: title, kind: kind, difficulty: difficulty, bpm: bpm, notes: notes)
    }

    // MIDI numbers in C major around middle C.
    private static let C = 60, D = 62, E = 64, F = 65, G = 67, A = 69, B = 71, C5 = 72, D5 = 74, E5 = 76, F5 = 77, G5 = 79

    static let twinkle = make("twinkle", "Twinkle Twinkle", .song, .easy, bpm: 90, [
        (C, 1), (C, 1), (G, 1), (G, 1), (A, 1), (A, 1), (G, 2),
        (F, 1), (F, 1), (E, 1), (E, 1), (D, 1), (D, 1), (C, 2),
        (G, 1), (G, 1), (F, 1), (F, 1), (E, 1), (E, 1), (D, 2),
        (G, 1), (G, 1), (F, 1), (F, 1), (E, 1), (E, 1), (D, 2),
        (C, 1), (C, 1), (G, 1), (G, 1), (A, 1), (A, 1), (G, 2),
        (F, 1), (F, 1), (E, 1), (E, 1), (D, 1), (D, 1), (C, 2),
    ])

    static let maryLamb = make("mary", "Mary Had a Little Lamb", .song, .easy, bpm: 100, [
        (E, 1), (D, 1), (C, 1), (D, 1), (E, 1), (E, 1), (E, 2),
        (D, 1), (D, 1), (D, 2), (E, 1), (G, 1), (G, 2),
        (E, 1), (D, 1), (C, 1), (D, 1), (E, 1), (E, 1), (E, 1), (E, 1),
        (D, 1), (D, 1), (E, 1), (D, 1), (C, 4),
    ])

    static let birthday = make("birthday", "Happy Birthday", .song, .medium, bpm: 90, [
        (G, 0.75), (G, 0.25), (A, 1), (G, 1), (C5, 1), (B, 2),
        (G, 0.75), (G, 0.25), (A, 1), (G, 1), (D5, 1), (C5, 2),
        (G, 0.75), (G, 0.25), (G5, 1), (E5, 1), (C5, 1), (B, 1), (A, 1),
        (F5, 0.75), (F5, 0.25), (E5, 1), (C5, 1), (D5, 1), (C5, 2),
    ])

    /// Sa Re Ga Ma Pa Dha Ni Sa: the swara scale used in Sri Lankan and Indian music (here with Sa = C).
    static let swara = make("swara", "Sa Re Ga Ma", .exercise, .medium, bpm: 80, [
        (C, 1), (D, 1), (E, 1), (F, 1), (G, 1), (A, 1), (B, 1), (C5, 2),
        (B, 1), (A, 1), (G, 1), (F, 1), (E, 1), (D, 1), (C, 2),
    ], syllables: ["Sa", "Re", "Ga", "Ma", "Pa", "Dha", "Ni", "Sa", "Ni", "Dha", "Pa", "Ma", "Ga", "Re", "Sa"])

    static let majorScale = make("scale", "Major Scale", .exercise, .easy, bpm: 80, [
        (C, 1), (D, 1), (E, 1), (F, 1), (G, 1), (A, 1), (B, 1), (C5, 2),
        (B, 1), (A, 1), (G, 1), (F, 1), (E, 1), (D, 1), (C, 2),
    ])

    static let arpeggio = make("arpeggio", "Major Arpeggio", .exercise, .medium, bpm: 90, [
        (C, 1), (E, 1), (G, 1), (C5, 2), (G, 1), (E, 1), (C, 2),
        (C, 1), (E, 1), (G, 1), (C5, 1), (E5, 1), (C5, 1), (G, 1), (E, 1), (C, 2),
    ])

    /// A 3-second melody that UI tests can finish quickly with simulated audio. Hidden in normal use.
    static let testTone = make("test-tone", "Test Tone", .exercise, .easy, bpm: 120, [(A, 2), (A, 2), (A, 2)])

    static var all: [Melody] { [twinkle, maryLamb, birthday, swara, majorScale, arpeggio] }

    static func catalogue(includeTestTone: Bool) -> [Melody] {
        includeTestTone ? all + [testTone] : all
    }

    static func melody(id: String) -> Melody? { (all + [testTone]).first { $0.id == id } }
}
