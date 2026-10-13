import SwiftUI

struct SessionDetailView: View {
    let session: PracticeSession

    var body: some View {
        List {
            Section {
                ScoreRingView(score: session.score).frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                StarRatingView(stars: session.stars).frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
            Section("Details") {
                row("Song", session.songTitle)
                row("Date", session.date.formatted(date: .long, time: .shortened))
                row("Time in tune", "\(Int(session.inTunePercent.rounded()))%")
                row("Average off-pitch", "\(Int(session.averageCentsOff.rounded())) cents")
                row("Length", String(format: "%d:%02d", Int(session.durationSeconds) / 60, Int(session.durationSeconds) % 60))
            }
        }
        .navigationTitle(session.songTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack { Text(title); Spacer(); Text(value).foregroundStyle(.secondary) }
            .accessibilityElement(children: .combine)
    }
}
