import Charts
import SwiftData
import SwiftUI

/// History and growth: streak, weekly average, score chart (pinch to zoom the date range) and session list.
struct ProgressDashboardView: View {
    @Query(sort: \PracticeSession.date, order: .reverse) private var sessions: [PracticeSession]
    @Query private var profiles: [VoiceProfile]
    @Environment(\.modelContext) private var context

    @State private var daysVisible = 30.0
    @State private var zoomStart = 30.0

    private var visibleSessions: [PracticeSession] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -Int(daysVisible), to: .now) ?? .distantPast
        return sessions.filter { $0.date >= cutoff }
    }

    private var streak: Int { StreakCalculator.currentStreak(dates: sessions.map(\.date)) }

    private var weeklyAverage: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
        let recent = sessions.filter { $0.date >= cutoff }
        guard !recent.isEmpty else { return 0 }
        return recent.map(\.score).reduce(0, +) / recent.count
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    tile("Practice streak", "\(streak) \(streak == 1 ? "day" : "days")", "flame.fill")
                    tile("Avg score (week)", "\(weeklyAverage)", "star.fill")
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                NavigationLink(value: ProgressRoute.rangeTest) {
                    HStack {
                        Image(systemName: "waveform.path").foregroundStyle(Theme.brand)
                        VStack(alignment: .leading) {
                            Text("Your voice range").font(.headline)
                            if let profile = profiles.first {
                                Text("\(profile.rangeDescription) · \(profile.voiceTypeName)").foregroundStyle(.secondary)
                            } else {
                                Text("Take the range test").foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("Score over time · pinch to zoom") {
                if visibleSessions.isEmpty {
                    Text("Sing a song and your scores will appear here.").foregroundStyle(.secondary)
                } else {
                    Chart(visibleSessions) { session in
                        LineMark(x: .value("Date", session.date), y: .value("Score", session.score))
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Date", session.date), y: .value("Score", session.score))
                    }
                    .chartYScale(domain: 0...100)
                    .frame(height: 200)
                    .accessibilityLabel("Score chart for the last \(Int(daysVisible)) days")
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in daysVisible = min(90, max(7, zoomStart / value.magnification)) }
                            .onEnded { _ in zoomStart = daysVisible }
                    )
                }
            }

            Section("History") {
                ForEach(sessions) { session in
                    NavigationLink(value: session) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(session.songTitle).font(.headline)
                                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(session.score)").font(.title3.bold()).foregroundStyle(Theme.brand)
                        }
                    }
                    .accessibilityIdentifier("history-row")
                }
                .onDelete { offsets in
                    offsets.map { sessions[$0] }.forEach { context.delete($0) }
                    try? context.save()
                }
            }
        }
        .navigationTitle("Progress")
        .navigationDestination(for: PracticeSession.self) { SessionDetailView(session: $0) }
        .navigationDestination(for: ProgressRoute.self) { _ in RangeTestView() }
    }

    private func tile(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(Theme.close)
            Text(value).font(.system(.title2, design: .rounded).bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glowCard()
    }
}

enum ProgressRoute: Hashable { case rangeTest }
