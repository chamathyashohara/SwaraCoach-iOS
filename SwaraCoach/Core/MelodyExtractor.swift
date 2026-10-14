import Foundation

/// Turns a recording of ONE melody line (a voice, humming or a single instrument) into a list of notes the
/// app can use as a practice target.
///
/// Steps: (1) run the YIN pitch detector over short overlapping frames, (2) smooth the readings with the same
/// median filter the live tuner uses, (3) group consecutive frames of similar pitch into notes, and
/// (4) drop notes that are too short to be real and join notes that were split by a tiny gap.
/// A full band recording has many notes at once, so a monophonic detector cannot follow it reliably:
/// the result is a best-effort melody, and the UI says so.
enum MelodyExtractor {
    struct Settings {
        var windowSize = 2048          // samples analysed per frame
        var hopSize = 512              // samples between frames
        var minNoteSeconds = 0.12      // shorter blips are treated as noise
        var maxGapSeconds = 0.08       // a dropout this short stays inside the same note
        var maxSeconds = 90.0          // only the first 90 seconds are analysed
        var leadInSeconds = 0.5        // silence kept before the first note
    }

    /// Pitch of every frame as a fractional MIDI number, or nil for silence / unclear sound.
    static func pitchTrack(samples: [Float], sampleRate: Double, settings: Settings = Settings()) -> [Double?] {
        let detector = PitchDetector()
        let limit = min(samples.count, Int(settings.maxSeconds * sampleRate))
        var track: [Double?] = []
        var start = 0
        while start + settings.windowSize <= limit {
            let frame = Array(samples[start..<start + settings.windowSize])
            if let frequency = detector.detect(samples: frame, sampleRate: sampleRate) {
                track.append(Note(frequency: frequency).midi)
            } else {
                track.append(nil)
            }
            start += settings.hopSize
        }
        return track
    }

    /// Groups a pitch track into notes. Times are in seconds; the first note starts `leadInSeconds` after 0 at most.
    static func notes(from track: [Double?], secondsPerFrame: Double, settings: Settings = Settings()) -> [MelodyNote] {
        var smoother = PitchSmoother(size: 5)
        var found: [MelodyNote] = []
        let maxGapFrames = max(1, Int((settings.maxGapSeconds / secondsPerFrame).rounded()))

        var active = false
        var sum = 0.0
        var count = 0
        var startFrame = 0
        var lastFrame = 0

        func closeNote() {
            let length = Double(lastFrame - startFrame + 1) * secondsPerFrame
            if length >= settings.minNoteSeconds {
                found.append(MelodyNote(start: Double(startFrame) * secondsPerFrame, length: length,
                                        midi: Int((sum / Double(count)).rounded())))
            }
            active = false
        }

        for (index, raw) in track.enumerated() {
            guard let midi = smoother.smooth(raw) else {
                if active && index - lastFrame > maxGapFrames { closeNote() }
                continue
            }
            if active, abs(midi - sum / Double(count)) <= 0.75, index - lastFrame <= maxGapFrames + 1 {
                sum += midi
                count += 1
                lastFrame = index
            } else {
                if active { closeNote() }
                active = true
                sum = midi
                count = 1
                startFrame = index
                lastFrame = index
            }
        }
        if active { closeNote() }

        // Join two notes of the same pitch that are separated by a very short gap.
        var merged: [MelodyNote] = []
        for note in found {
            if var previous = merged.last, previous.midi == note.midi,
               note.start - (previous.start + previous.length) <= settings.maxGapSeconds {
                previous.length = note.start + note.length - previous.start
                merged[merged.count - 1] = previous
            } else {
                merged.append(note)
            }
        }

        // Trim the silence before the first note so practice starts almost immediately.
        guard let first = merged.first else { return [] }
        let shift = max(0, first.start - settings.leadInSeconds)
        return merged.map { MelodyNote(start: $0.start - shift, length: $0.length, midi: $0.midi) }
    }

    /// Convenience: samples straight to notes.
    static func extract(samples: [Float], sampleRate: Double, settings: Settings = Settings()) -> [MelodyNote] {
        let track = pitchTrack(samples: samples, sampleRate: sampleRate, settings: settings)
        return notes(from: track, secondsPerFrame: Double(settings.hopSize) / sampleRate, settings: settings)
    }

    /// A rough difficulty label from the pitch span of the melody.
    static func difficulty(for notes: [MelodyNote]) -> Melody.Difficulty {
        guard let low = notes.map(\.midi).min(), let high = notes.map(\.midi).max() else { return .easy }
        switch high - low {
        case ..<8: return .easy
        case 8..<13: return .medium
        default: return .hard
        }
    }
}
