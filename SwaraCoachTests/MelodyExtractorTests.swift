import SwiftData
import XCTest
@testable import SwaraCoach

final class MelodyExtractorTests: XCTestCase {
    private let sampleRate = 22050.0

    private func sine(_ frequency: Double, seconds: Double) -> [Float] {
        (0..<Int(seconds * sampleRate)).map { Float(0.5 * sin(2 * Double.pi * frequency * Double($0) / sampleRate)) }
    }

    private func silence(_ seconds: Double) -> [Float] { [Float](repeating: 0, count: Int(seconds * sampleRate)) }

    func testExtractsThreeSeparatedNotes() {
        let samples = silence(0.2) + sine(440, seconds: 0.5) + silence(0.3) + sine(523.25, seconds: 0.5)
            + silence(0.3) + sine(659.26, seconds: 0.5)
        let notes = MelodyExtractor.extract(samples: samples, sampleRate: sampleRate)
        XCTAssertEqual(notes.map(\.midi), [69, 72, 76])
        for note in notes { XCTAssertEqual(note.length, 0.5, accuracy: 0.2) }
        XCTAssertLessThan(notes[0].start, 0.3, "silence before the first note is trimmed to the lead-in")
        XCTAssertGreaterThan(notes[1].start, notes[0].start + notes[0].length)
    }

    func testSilenceGivesNoNotes() {
        XCTAssertTrue(MelodyExtractor.extract(samples: silence(2), sampleRate: sampleRate).isEmpty)
    }

    func testShortBlipsAreIgnored() {
        let track: [Double?] = [69, nil, nil, nil, nil, nil, 72, 72, nil, nil, nil, nil, nil]
        XCTAssertTrue(MelodyExtractor.notes(from: track, secondsPerFrame: 0.023).isEmpty)
    }

    func testTinyDropoutDoesNotSplitANote() {
        var track = [Double?](repeating: 69.1, count: 10)
        track[5] = nil
        let notes = MelodyExtractor.notes(from: track, secondsPerFrame: 0.023)
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes.first?.midi, 69)
    }

    func testDifficultyFromRange() {
        func melody(_ lo: Int, _ hi: Int) -> [MelodyNote] {
            [MelodyNote(start: 0, length: 1, midi: lo), MelodyNote(start: 1, length: 1, midi: hi)]
        }
        XCTAssertEqual(MelodyExtractor.difficulty(for: melody(60, 64)), .easy)
        XCTAssertEqual(MelodyExtractor.difficulty(for: melody(60, 69)), .medium)
        XCTAssertEqual(MelodyExtractor.difficulty(for: melody(55, 72)), .hard)
    }

    @MainActor func testImportedSongRoundTripsThroughSwiftData() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let notes = [MelodyNote(start: 0, length: 0.5, midi: 60), MelodyNote(start: 0.5, length: 0.5, midi: 64),
                     MelodyNote(start: 1, length: 1, midi: 67)]
        container.mainContext.insert(ImportedSong(title: "My tune", notes: notes))
        try container.mainContext.save()

        let saved = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<ImportedSong>()).first)
        XCTAssertEqual(saved.notes, notes)
        XCTAssertEqual(saved.melody.title, "My tune")
        XCTAssertEqual(saved.melody.duration, 2, accuracy: 0.001)
        XCTAssertEqual(saved.melody.targetMidi(at: 0.7), 64)
        XCTAssertTrue(saved.id.hasPrefix("imported-"))
    }
}
