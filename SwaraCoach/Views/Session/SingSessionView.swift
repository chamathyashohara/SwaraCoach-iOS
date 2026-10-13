import SwiftData
import SwiftUI

/// Full-screen live singing session. Shows the pitch graph while singing and the results when the song ends.
struct SingSessionView: View {
    let melody: Melody
    @State private var model: SessionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var typeSize

    init(melody: Melody) {
        self.melody = melody
        _model = State(initialValue: SessionViewModel(melody: melody))
    }

    var body: some View {
        ZStack {
            Theme.stage.ignoresSafeArea()
            switch model.phase {
            case .finished:
                ResultsView(model: model, onRetry: { model.reset() }, onDone: { dismiss() })
                    .transition(.opacity)
            default:
                sessionContent
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut, value: model.phase)
        .onChange(of: model.phase) { _, phase in
            if phase == .finished { model.save(in: context) }
        }
        .onDisappear { model.cancel() }
    }

    private var sessionContent: some View {
        VStack(spacing: 16) {
            HStack {
                Button { model.cancel(); dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2) }
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("closeSession")
                Spacer()
                Text(melody.title).font(.headline)
                Spacer()
                Color.clear.frame(width: 28, height: 28)
            }
            .foregroundStyle(.white)

            if typeSize < .accessibility1 {
                PitchGraphView(melody: melody, store: model.store, startDate: model.startDate)
                    .frame(minHeight: 200, maxHeight: 320)
            }

            ProgressView(value: model.progress).tint(Theme.brandLight)

            readout

            if let hint = model.hint {
                Label(hint, systemImage: "ear").font(.callout).foregroundStyle(Theme.close)
            }

            Spacer(minLength: 0)

            switch model.phase {
            case .ready:
                Button { Task { await model.begin() } } label: {
                    Label("Start", systemImage: "play.fill").font(.headline).frame(maxWidth: .infinity).padding()
                        .background(Theme.brand, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                        .foregroundStyle(.white)
                }
                .accessibilityIdentifier("beginSinging")
            case .failed(let message):
                Text(message).font(.callout).foregroundStyle(Theme.off).multilineTextAlignment(.center)
                Button("Try again") { model.reset() }.buttonStyle(.borderedProminent)
            default:
                EmptyView()
            }
        }
        .padding()
    }

    /// Big note name with cents, always paired with a word so colour is never the only signal.
    private var readout: some View {
        VStack(spacing: 4) {
            Text(model.hasPitch ? model.noteName : "–")
                .font(.system(.largeTitle, design: .rounded).bold())
            if model.hasPitch {
                Text("\(model.cents >= 0 ? "+" : "")\(Int(model.cents.rounded())) cents · \(Theme.word(forCents: model.cents))")
                    .font(.headline).foregroundStyle(Theme.color(forCents: model.cents))
            } else if let syllable = model.currentSyllable {
                Text(syllable).font(.headline).foregroundStyle(Theme.brandLight)
            } else {
                Text(model.phase == .running ? "Listening…" : "Ready").font(.headline).foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .glowCard()
        .accessibilityElement(children: .combine)
    }
}
