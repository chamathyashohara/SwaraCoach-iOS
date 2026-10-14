import Foundation
import SwiftData

/// A song the user imported. Only the extracted melody (notes) is stored, never the audio file.
@Model
final class ImportedSong {
    var id: String
    var title: String
    var createdDate: Date
    var notesData: Data

    private struct StoredNote: Codable {
        var start: Double
        var length: Double
        var midi: Int
    }

    init(title: String, notes: [MelodyNote], date: Date = .now) {
        self.id = "imported-" + UUID().uuidString
        self.title = title
        self.createdDate = date
        self.notesData = (try? JSONEncoder().encode(notes.map { StoredNote(start: $0.start, length: $0.length, midi: $0.midi) })) ?? Data()
    }

    var notes: [MelodyNote] {
        let stored = (try? JSONDecoder().decode([StoredNote].self, from: notesData)) ?? []
        return stored.map { MelodyNote(start: $0.start, length: $0.length, midi: $0.midi) }
    }

    /// The practice target. One beat is one second (60 bpm), because the notes were measured in seconds.
    var melody: Melody {
        let notes = notes
        return Melody(id: id, title: title, kind: .imported, difficulty: MelodyExtractor.difficulty(for: notes), bpm: 60, notes: notes)
    }
}
