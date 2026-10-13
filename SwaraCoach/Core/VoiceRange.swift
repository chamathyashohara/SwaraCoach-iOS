import Foundation

enum VoiceType: String, CaseIterable {
    case bass = "Bass", baritone = "Baritone", tenor = "Tenor", alto = "Alto", soprano = "Soprano"

    /// Classifies a voice from the centre of its comfortable range (average of lowest and highest MIDI note).
    /// Boundaries sit halfway between typical centres: bass 52, baritone 57, tenor 60, alto 65, soprano 72.
    static func classify(lowest: Int, highest: Int) -> VoiceType {
        let centre = Double(lowest + highest) / 2
        switch centre {
        case ..<54.5: return .bass
        case ..<58.5: return .baritone
        case ..<62.5: return .tenor
        case ..<68.5: return .alto
        default: return .soprano
        }
    }
}

enum StreakCalculator {
    /// Number of consecutive days, ending today or yesterday, on which at least one session was completed.
    static func currentStreak(dates: [Date], today: Date = .now, calendar: Calendar = .current) -> Int {
        let days = Set(dates.map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: today)
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day), days.contains(yesterday) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
}
