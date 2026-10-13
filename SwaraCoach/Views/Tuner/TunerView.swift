import SwiftUI

/// Free tuner: note name, frequency, gauge and the "singing detected" chip from SoundAnalysis.
struct TunerView: View {
    @State private var model = TunerViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(model.hasPitch ? model.noteName : "–")
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .accessibilityIdentifier("tunerNote")
                    Text(model.hasPitch
                         ? "\(String(format: "%.1f", model.frequency)) Hz · \(model.cents >= 0 ? "+" : "")\(Int(model.cents.rounded())) cents"
                         : "Sing or play a note")
                        .font(.headline).foregroundStyle(.secondary)
                    if model.hasPitch {
                        Text(Theme.word(forCents: model.cents)).font(.headline).foregroundStyle(Theme.color(forCents: model.cents))
                    }
                }
                .frame(maxWidth: .infinity)
                .glowCard()

                TunerGaugeView(cents: model.hasPitch ? model.cents : 0, active: model.hasPitch)
                    .padding(.horizontal)

                singingChip

                if let error = model.errorMessage {
                    Text(error).font(.callout).foregroundStyle(Theme.off).multilineTextAlignment(.center)
                }
            }
            .padding()
        }
        .navigationTitle("Tuner")
        .sensoryFeedback(.success, trigger: model.isInTune) { _, inTune in inTune }
        .task { await model.start() }
        .onDisappear { model.stop() }
    }

    /// Shows the live result of the on-device sound classifier.
    private var singingChip: some View {
        let state = model.singingState
        let text = state.isSinging ? "Singing detected · \(Int((state.confidence * 100).rounded()))%"
                                   : (state.label == "Listening" ? "Listening…" : "Not singing · \(state.label)")
        return Label(text, systemImage: state.isSinging ? "music.mic" : "ear")
            .font(.subheadline.bold())
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(state.isSinging ? Theme.inTune.opacity(0.25) : Color.secondary.opacity(0.15)))
            .accessibilityIdentifier("singingChip")
            .animation(.easeInOut, value: state.isSinging)
    }
}
