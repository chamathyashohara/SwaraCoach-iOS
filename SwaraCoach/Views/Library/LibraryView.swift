import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Home of the Sing tab: songs and exercises, a daily warm-up card and the user's best stars.
struct LibraryView: View {
    @Query private var sessions: [PracticeSession]
    @Query(sort: \ImportedSong.createdDate, order: .reverse) private var importedSongs: [ImportedSong]
    @State private var kind: Melody.Kind = .song
    @State private var showImporter = false
    @State private var isAnalysing = false
    @State private var importError: String?

    private var melodies: [Melody] {
        if kind == .imported { return importedSongs.map(\.melody) }
        return MelodyLibrary.catalogue(includeTestTone: AppEnvironment.isUITesting).filter { $0.kind == kind }
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
                    Text("My Songs").tag(Melody.Kind.imported)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                if kind == .imported { importSection }

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
                    .deleteDisabled(kind != .imported)
                    .contextMenu {
                        if bestStars(for: melody) > 0 {
                            Button("Reset best", systemImage: "arrow.counterclockwise", role: .destructive) { resetBest(melody) }
                        }
                    }
                }
                .onDelete { deleteImported(at: $0) }
            }
        }
        .navigationTitle("Sing")
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.audio]) { result in
            if case .success(let url) = result { Task { await importSong(from: url) } }
        }
        .alert("Couldn't import this song", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
        .navigationDestination(for: Melody.self) { SongDetailView(melody: $0) }
    }

    @Environment(\.modelContext) private var context

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { showImporter = true } label: {
                HStack {
                    if isAnalysing { ProgressView() } else { Image(systemName: "square.and.arrow.down") }
                    Text(isAnalysing ? "Finding the melody…" : "Import a song file")
                }
                .font(.headline)
            }
            .disabled(isAnalysing)
            .accessibilityIdentifier("importButton")
            Text("Pick an audio file (MP3, M4A, WAV). The app finds the melody in the first 90 seconds and lets you sing along. It works best with a solo voice, humming or one instrument; a full band recording can give a messy melody. Only the notes are kept, never the audio.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .listRowBackground(Color.clear)
    }

    @MainActor private func importSong(from url: URL) async {
        isAnalysing = true
        defer { isAnalysing = false }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let notes = try await Task.detached(priority: .userInitiated) {
                try AudioFileAnalyzer.extractMelody(from: url)
            }.value
            context.insert(ImportedSong(title: url.deletingPathExtension().lastPathComponent, notes: notes))
            try context.save()
        } catch {
            importError = error.localizedDescription
        }
    }

    private func deleteImported(at offsets: IndexSet) {
        for index in offsets {
            let song = importedSongs[index]
            sessions.filter { $0.songID == song.id }.forEach { context.delete($0) }
            context.delete(song)
        }
        try? context.save()
    }

    private func resetBest(_ melody: Melody) {
        sessions.filter { $0.songID == melody.id }.forEach { context.delete($0) }
        try? context.save()
    }

    private func formatted(_ seconds: Double) -> String {
        String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
}
