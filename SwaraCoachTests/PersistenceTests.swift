import SwiftData
import XCTest
@testable import SwaraCoach

@MainActor
final class PersistenceTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        ModelContext(try Persistence.makeContainer(inMemory: true))
    }

    func testSaveAndFetchSessions() throws {
        let context = try makeContext()
        let result = ScoreResult(score: 80, inTunePercent: 85, averageCentsOff: 14, stars: 2)
        context.insert(PracticeSession(songID: "twinkle", songTitle: "Twinkle Twinkle", result: result, duration: 60))
        context.insert(PracticeSession(songID: "mary", songTitle: "Mary", result: result, duration: 40))
        try context.save()

        let twinkle = try context.fetch(FetchDescriptor<PracticeSession>(predicate: #Predicate { $0.songID == "twinkle" }))
        XCTAssertEqual(twinkle.count, 1)
        XCTAssertEqual(twinkle.first?.score, 80)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PracticeSession>()).count, 2)
    }

    func testDeleteSession() throws {
        let context = try makeContext()
        let session = PracticeSession(songID: "a", songTitle: "A", result: .empty, duration: 1)
        context.insert(session)
        try context.save()
        context.delete(session)
        try context.save()
        XCTAssertTrue(try context.fetch(FetchDescriptor<PracticeSession>()).isEmpty)
    }

    func testVoiceProfileDescribesRange() {
        let profile = VoiceProfile(lowestMidi: 48, highestMidi: 72)
        XCTAssertEqual(profile.voiceTypeName, "Tenor")
        XCTAssertEqual(profile.rangeDescription, "C3 – C5")
    }

    func testSessionViewModelSavesAndReportsPreviousBest() throws {
        let context = try makeContext()
        let model = SessionViewModel(melody: MelodyLibrary.twinkle)
        context.insert(PracticeSession(songID: "twinkle", songTitle: "Twinkle Twinkle",
                                       result: ScoreResult(score: 70, inTunePercent: 70, averageCentsOff: 20, stars: 2), duration: 60))
        try context.save()
        model.save(in: context)
        XCTAssertEqual(model.previousBest, 70)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PracticeSession>()).count, 2)
    }
}

@MainActor
final class RangeTestViewModelTests: XCTestCase {
    /// Feeds readings of one steady note for `seconds` at the detector's real rate.
    private func hold(_ midi: Double, from start: Double, seconds: Double, into model: RangeTestViewModel) {
        var time = start
        while time <= start + seconds {
            model.handle(PitchReading(time: time, midi: midi, frequency: Note.frequency(forMidi: midi)))
            time += 0.023
        }
    }

    func testRangeTestAcceptsSteadyNotes() {
        let model = RangeTestViewModel()
        hold(48, from: 0, seconds: 2.2, into: model)
        XCTAssertEqual(model.step, .high)
        XCTAssertEqual(model.lowestMidi, 48)
        hold(72, from: 3, seconds: 2.2, into: model)
        XCTAssertEqual(model.step, .done)
        XCTAssertEqual(model.highestMidi, 72)
        XCTAssertEqual(model.voiceType, .tenor)
    }

    func testWobblyNoteIsNotAccepted() {
        let model = RangeTestViewModel()
        var time = 0.0
        for i in 0..<200 {   // alternates by a whole tone, never steady
            model.handle(PitchReading(time: time, midi: i % 2 == 0 ? 50 : 52, frequency: nil))
            time += 0.023
        }
        XCTAssertEqual(model.step, .low)
    }
}
