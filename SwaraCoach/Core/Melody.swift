import Foundation

/// One note of a melody. `start` and `length` are measured in beats.
struct MelodyNote: Hashable {
    var start: Double
    var length: Double
    var midi: Int
    var syllable: String? = nil
}

/// A song or exercise that the user sings along with.
struct Melody: Identifiable, Hashable {
    enum Kind: String { case song = "Song", exercise = "Exercise" }
    enum Difficulty: String, CaseIterable { case easy = "Easy", medium = "Medium", hard = "Hard" }

    let id: String
    let title: String
    let kind: Kind
    let difficulty: Difficulty
    let bpm: Double
    let notes: [MelodyNote]

    var secondsPerBeat: Double { 60 / bpm }

    /// Length of the melody in seconds (end of the last note).
    var duration: Double {
        (notes.map { $0.start + $0.length }.max() ?? 0) * secondsPerBeat
    }

    /// Total time, in seconds, during which a target note is sounding.
    var voicedSeconds: Double { notes.reduce(0) { $0 + $1.length } * secondsPerBeat }

    var lowestMidi: Int { notes.map(\.midi).min() ?? 60 }
    var highestMidi: Int { notes.map(\.midi).max() ?? 60 }

    /// The target note at a time (seconds from the start), or nil during a rest / outside the melody.
    func note(at time: Double) -> MelodyNote? {
        let beat = time / secondsPerBeat
        return notes.first { beat >= $0.start && beat < $0.start + $0.length }
    }

    func targetMidi(at time: Double) -> Int? { note(at: time)?.midi }
}
