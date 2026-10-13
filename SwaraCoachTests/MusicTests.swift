import XCTest
@testable import SwaraCoach

final class NoteTests: XCTestCase {
    func testA440IsA4() {
        let note = Note(frequency: 440)
        XCTAssertEqual(note.name, "A4")
        XCTAssertEqual(note.cents, 0, accuracy: 0.01)
    }

    func testMiddleC() { XCTAssertEqual(Note(frequency: 261.63).name, "C4") }

    func testCentsSharpAndFlat() {
        XCTAssertEqual(Note(midi: 69.25).cents, 25, accuracy: 0.001)
        XCTAssertEqual(Note(midi: 68.8).cents, -20, accuracy: 0.001)   // 68.8 is nearest to A4 (69) so -20 cents
    }

    func testFrequencyRoundTrip() {
        XCTAssertEqual(Note(midi: 60).frequency, 261.6256, accuracy: 0.001)
    }

    func testNamesForLowAndHighMidi() {
        XCTAssertEqual(Note.name(forMidi: 0), "C-1")
        XCTAssertEqual(Note.name(forMidi: 21), "A0")
        XCTAssertEqual(Note.name(forMidi: 108), "C8")
    }
}

final class MelodyTests: XCTestCase {
    func testTargetAtTime() {
        let melody = MelodyLibrary.twinkle                   // 90 bpm: one beat = 0.667 s
        XCTAssertEqual(melody.targetMidi(at: 0.1), 60)       // first note C4
        XCTAssertEqual(melody.targetMidi(at: 0.667 * 2 + 0.1), 67)   // third note G4
        XCTAssertNil(melody.targetMidi(at: melody.duration + 5))
    }

    func testRestsAreGaps() {
        // Notes are 90% of their beat length, so just before the next beat there is a short gap.
        let melody = MelodyLibrary.twinkle
        XCTAssertNil(melody.targetMidi(at: melody.secondsPerBeat * 0.97))
    }

    func testLibraryIsValid() {
        XCTAssertGreaterThanOrEqual(MelodyLibrary.all.count, 6)
        XCTAssertEqual(Set(MelodyLibrary.all.map(\.id)).count, MelodyLibrary.all.count, "ids must be unique")
        for melody in MelodyLibrary.all {
            XCTAssertFalse(melody.notes.isEmpty, melody.title)
            XCTAssertTrue(melody.notes.allSatisfy { (36...96).contains($0.midi) }, "\(melody.title) pitch out of singable range")
            XCTAssertGreaterThan(melody.duration, 5, melody.title)
            // notes must not overlap
            let sorted = melody.notes.sorted { $0.start < $1.start }
            for (a, b) in zip(sorted, sorted.dropFirst()) { XCTAssertLessThanOrEqual(a.start + a.length, b.start + 0.0001, melody.title) }
        }
    }

    func testSwaraExerciseHasSyllables() {
        let syllables = MelodyLibrary.swara.notes.compactMap(\.syllable)
        XCTAssertEqual(syllables.count, MelodyLibrary.swara.notes.count)
        XCTAssertEqual(syllables.first, "Sa")
    }
}

final class ScoreCalculatorTests: XCTestCase {
    func testOctaveErrorsAreForgiven() {
        XCTAssertEqual(ScoreCalculator.centsError(sung: 48, target: 60), 0, accuracy: 0.01)
        XCTAssertEqual(ScoreCalculator.centsError(sung: 72, target: 60), 0, accuracy: 0.01)
    }

    func testQuarterToneIsFiftyCents() {
        XCTAssertEqual(ScoreCalculator.centsError(sung: 60.5, target: 60), 50, accuracy: 0.01)
        XCTAssertEqual(ScoreCalculator.centsError(sung: 59.5, target: 60), 50, accuracy: 0.01)
    }

    func testTritoneIsLargestError() {
        XCTAssertEqual(ScoreCalculator.centsError(sung: 66, target: 60), 600, accuracy: 0.01)
    }

    func testStarThresholds() {
        XCTAssertEqual(ScoreCalculator.stars(forScore: 100), 3)
        XCTAssertEqual(ScoreCalculator.stars(forScore: 85), 3)
        XCTAssertEqual(ScoreCalculator.stars(forScore: 84), 2)
        XCTAssertEqual(ScoreCalculator.stars(forScore: 65), 2)
        XCTAssertEqual(ScoreCalculator.stars(forScore: 40), 1)
        XCTAssertEqual(ScoreCalculator.stars(forScore: 39), 0)
    }

    /// A singer who follows the melody perfectly, sampled at the real detector rate.
    private func perfectSamples(for melody: Melody, offsetCents: Double = 0, singing: Bool = true) -> [PitchSample] {
        let interval = 1024.0 / 44100.0
        return stride(from: 0.0, to: melody.duration, by: interval).compactMap { time in
            guard let target = melody.targetMidi(at: time) else { return nil }
            return PitchSample(time: time, midi: Double(target) + offsetCents / 100, isSinging: singing)
        }
    }

    func testPerfectSingingGetsThreeStars() {
        let melody = MelodyLibrary.twinkle
        let result = ScoreCalculator.score(samples: perfectSamples(for: melody), melody: melody)
        XCTAssertGreaterThanOrEqual(result.score, 95)
        XCTAssertEqual(result.stars, 3)
        XCTAssertEqual(result.averageCentsOff, 0, accuracy: 1)
    }

    func testSingingAQuarterToneFlatStillCountsAsClose() {
        let melody = MelodyLibrary.twinkle
        let result = ScoreCalculator.score(samples: perfectSamples(for: melody, offsetCents: -30), melody: melody)
        XCTAssertEqual(result.averageCentsOff, 30, accuracy: 1)
        XCTAssertGreaterThan(result.inTunePercent, 99)
    }

    func testVeryOffPitchScoresLow() {
        let melody = MelodyLibrary.twinkle
        let result = ScoreCalculator.score(samples: perfectSamples(for: melody, offsetCents: 300), melody: melody)
        XCTAssertLessThan(result.score, 40)
        XCTAssertEqual(result.stars, 0)
    }

    func testNotSingingSamplesAreIgnored() {
        let melody = MelodyLibrary.twinkle
        let result = ScoreCalculator.score(samples: perfectSamples(for: melody, singing: false), melody: melody)
        XCTAssertEqual(result, .empty)
    }

    func testSilenceScoresZero() {
        XCTAssertEqual(ScoreCalculator.score(samples: [], melody: MelodyLibrary.twinkle), .empty)
    }

    func testSingingOnlyHalfTheSongLowersScore() {
        let melody = MelodyLibrary.twinkle
        let all = perfectSamples(for: melody)
        let half = Array(all.prefix(all.count / 2))
        let fullScore = ScoreCalculator.score(samples: all, melody: melody).score
        let halfScore = ScoreCalculator.score(samples: half, melody: melody).score
        XCTAssertLessThan(halfScore, fullScore)
    }

    func testReactionWindowForgivesLateSinger() {
        // A singer who is 0.1 s late still matches the previous note.
        let melody = MelodyLibrary.swara
        let late = perfectSamples(for: melody).map { PitchSample(time: $0.time + 0.1, midi: $0.midi, isSinging: true) }
        let result = ScoreCalculator.score(samples: late, melody: melody)
        XCTAssertGreaterThan(result.inTunePercent, 95)
    }
}

final class VoiceTypeTests: XCTestCase {
    func testClassification() {
        XCTAssertEqual(VoiceType.classify(lowest: 40, highest: 64), .bass)        // E2-E4
        XCTAssertEqual(VoiceType.classify(lowest: 45, highest: 69), .baritone)    // A2-A4
        XCTAssertEqual(VoiceType.classify(lowest: 48, highest: 72), .tenor)       // C3-C5
        XCTAssertEqual(VoiceType.classify(lowest: 53, highest: 77), .alto)        // F3-F5
        XCTAssertEqual(VoiceType.classify(lowest: 60, highest: 84), .soprano)     // C4-C6
    }
}

final class StreakTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private func date(_ day: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 12))! }

    func testConsecutiveDays() {
        XCTAssertEqual(StreakCalculator.currentStreak(dates: [date(13), date(12), date(11)], today: date(13), calendar: calendar), 3)
    }

    func testStreakSurvivesUntilEndOfNextDay() {
        XCTAssertEqual(StreakCalculator.currentStreak(dates: [date(12), date(11)], today: date(13), calendar: calendar), 2)
    }

    func testGapBreaksStreak() {
        XCTAssertEqual(StreakCalculator.currentStreak(dates: [date(13), date(11)], today: date(13), calendar: calendar), 1)
        XCTAssertEqual(StreakCalculator.currentStreak(dates: [date(10)], today: date(13), calendar: calendar), 0)
    }

    func testMultipleSessionsSameDayCountOnce() {
        XCTAssertEqual(StreakCalculator.currentStreak(dates: [date(13), date(13), date(12)], today: date(13), calendar: calendar), 2)
    }
}
