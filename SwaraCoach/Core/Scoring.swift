import Foundation

/// One analysed moment of singing. `time` is seconds since the start of the session.
struct PitchSample {
    var time: Double
    var midi: Double?        // fractional MIDI note, nil when no clear pitch
    var isSinging: Bool      // result of the SoundAnalysis classifier at this time
}

struct ScoreResult: Equatable {
    var score: Int
    var inTunePercent: Double
    var averageCentsOff: Double
    var stars: Int

    static let empty = ScoreResult(score: 0, inTunePercent: 0, averageCentsOff: 0, stars: 0)
}

enum ScoreCalculator {
    /// Octave-tolerant error, in cents, between a sung pitch and a target note.
    /// Singing the melody an octave lower (or higher) is still "in tune", so the difference is folded into +-6 semitones.
    static func centsError(sung: Double, target: Int) -> Double {
        var diff = (sung - Double(target)).truncatingRemainder(dividingBy: 12)
        if diff > 6 { diff -= 12 } else if diff < -6 { diff += 12 }
        return abs(diff * 100)
    }

    static func stars(forScore score: Int) -> Int {
        score >= 85 ? 3 : score >= 65 ? 2 : score >= 40 ? 1 : 0
    }

    /// - Parameters:
    ///   - tolerance: cents within which a sample counts as "in tune".
    ///   - sampleInterval: seconds between samples, used to work out how many samples a perfect take would have.
    ///   - reactionWindow: singers react slightly late, so a sample may match the note from this long ago.
    static func score(samples: [PitchSample], melody: Melody, tolerance: Double = 50,
                      sampleInterval: Double = 1024.0 / 44100.0, reactionWindow: Double = 0.15) -> ScoreResult {
        var errors: [Double] = []
        for sample in samples where sample.isSinging {
            guard let midi = sample.midi else { continue }
            let targets = [melody.targetMidi(at: sample.time), melody.targetMidi(at: sample.time - reactionWindow)]
            let candidates = targets.compactMap { $0 }.map { centsError(sung: midi, target: $0) }
            if let best = candidates.min() { errors.append(best) }
        }
        guard !errors.isEmpty else { return .empty }

        let inTuneCount = errors.filter { $0 <= tolerance }.count
        let inTune = Double(inTuneCount) / Double(errors.count)
        let average = errors.reduce(0, +) / Double(errors.count)
        let expected = max(1, melody.voicedSeconds / sampleInterval)
        let coverage = min(1, Double(inTuneCount) / expected)
        let score = Int(((inTune * 0.8 + coverage * 0.2) * 100).rounded())
        return ScoreResult(score: score, inTunePercent: inTune * 100, averageCentsOff: average, stars: stars(forScore: score))
    }
}
