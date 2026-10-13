import Foundation
import SwiftData

/// One completed singing attempt. Only a summary is stored, never raw audio or raw samples.
@Model
final class PracticeSession {
    var songID: String
    var songTitle: String
    var date: Date
    var score: Int
    var inTunePercent: Double
    var averageCentsOff: Double
    var durationSeconds: Double
    var stars: Int

    init(songID: String, songTitle: String, result: ScoreResult, duration: Double, date: Date = .now) {
        self.songID = songID
        self.songTitle = songTitle
        self.date = date
        self.score = result.score
        self.inTunePercent = result.inTunePercent
        self.averageCentsOff = result.averageCentsOff
        self.stars = result.stars
        self.durationSeconds = duration
    }
}

/// The user's measured singing range. At most one row is kept.
@Model
final class VoiceProfile {
    var lowestMidi: Int
    var highestMidi: Int
    var voiceTypeName: String
    var testedDate: Date

    init(lowestMidi: Int, highestMidi: Int, testedDate: Date = .now) {
        self.lowestMidi = lowestMidi
        self.highestMidi = highestMidi
        self.voiceTypeName = VoiceType.classify(lowest: lowestMidi, highest: highestMidi).rawValue
        self.testedDate = testedDate
    }

    var rangeDescription: String { "\(Note.name(forMidi: lowestMidi)) – \(Note.name(forMidi: highestMidi))" }
}

enum Persistence {
    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        let schema = Schema([PracticeSession.self, VoiceProfile.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
