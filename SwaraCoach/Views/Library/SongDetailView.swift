import Charts
import SwiftData
import SwiftUI

/// Song details, past attempts and the Start button.
struct SongDetailView: View {
    let melody: Melody
    @Query private var attempts: [PracticeSession]
    @State private var activeMelody: Melody?

    init(melody: Melody) {
        self.melody = melody
        let id = melody.id
        _attempts = Query(filter: #Predicate<PracticeSession> { $0.songID == id }, sort: \.date)
    }

    private var best: Int? { attempts.map(\.score).max() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    detail("Difficulty", melody.difficulty.rawValue)
                    detail("Range", "\(Note.name(forMidi: melody.lowestMidi))–\(Note.name(forMidi: melody.highestMidi))")
                    detail("Tempo", "\(Int(melody.bpm)) bpm")
                }
                .glowCard()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Your attempts").font(.headline)
                    if attempts.isEmpty {
                        Text("No attempts yet. Put on headphones and sing!").foregroundStyle(.secondary)
                    } else {
                        Chart(attempts) { attempt in
                            LineMark(x: .value("Date", attempt.date), y: .value("Score", attempt.score))
                            PointMark(x: .value("Date", attempt.date), y: .value("Score", attempt.score))
                        }
                        .chartYScale(domain: 0...100)
                        .frame(height: 160)
                        Text("Personal best: \(best ?? 0)").font(.subheadline.bold())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glowCard()

                Button { activeMelody = melody } label: {
                    Label("Start singing", systemImage: "mic.fill")
                        .font(.headline).frame(maxWidth: .infinity).padding()
                        .background(Theme.brand, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                        .foregroundStyle(.white)
                }
                .accessibilityIdentifier("startButton")
            }
            .padding()
        }
        .navigationTitle(melody.title)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $activeMelody) { SingSessionView(melody: $0) }
    }

    private func detail(_ title: String, _ value: String) -> some View {
        VStack {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
        }
        .frame(maxWidth: .infinity)
    }
}
