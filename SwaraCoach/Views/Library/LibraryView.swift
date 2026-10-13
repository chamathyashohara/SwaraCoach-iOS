import SwiftData
import SwiftUI

/// Home of the Sing tab: songs and exercises, a daily warm-up card and the user's best stars.
struct LibraryView: View {
    @Query private var sessions: [PracticeSession]
    @State private var kind: Melody.Kind = .song

    private var melodies: [Melody] {
        MelodyLibrary.catalogue(includeTestTone: AppEnvironment.isUITesting).filter { $0.kind == kind }
    }

    private func bestStars(for melody: Melody) -> Int {
        sessions.filter { $0.songID == melody.id }.map(\.stars).max() ?? 0
    }

    var body: some View {
        List {
            Section {
                NavigationLink(value: MelodyLibrary.swara) {
                    HStack(spacing: 12) {
                        Image(systemName: "sunrise.fill").font(.title2).foregroundStyle(Theme.close)
                        VStack(alignment: .leading) {
                            Text("Daily warm-up").font(.headline)
                            Text("Sa Re Ga Ma · swara scale").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .glowCard()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                Picker("Type", selection: $kind) {
                    Text("Songs").tag(Melody.Kind.song)
                    Text("Exercises").tag(Melody.Kind.exercise)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                ForEach(melodies) { melody in
                    NavigationLink(value: melody) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(melody.title).font(.headline)
                                Text("\(melody.difficulty.rawValue) · \(formatted(melody.duration))")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            StarRatingView(stars: bestStars(for: melody), font: .footnote)
                        }
                    }
                    .accessibilityIdentifier("melody-\(melody.id)")
                    .contextMenu {
                        if bestStars(for: melody) > 0 {
                            Button("Reset best", systemImage: "arrow.counterclockwise", role: .destructive) { resetBest(melody) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Sing")
        .navigationDestination(for: Melody.self) { SongDetailView(melody: $0) }
    }

    @Environment(\.modelContext) private var context

    private func resetBest(_ melody: Melody) {
        sessions.filter { $0.songID == melody.id }.forEach { context.delete($0) }
        try? context.save()
    }

    private func formatted(_ seconds: Double) -> String {
        String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
}
