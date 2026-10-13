import SwiftUI

/// Score, stars and statistics after a session.
struct ResultsView: View {
    let model: SessionViewModel
    var onRetry: () -> Void
    var onDone: () -> Void

    private var message: String {
        switch model.result.stars {
        case 3: return "Great pitch control!"
        case 2: return "Nice work, keep practising."
        case 1: return "Good start. Try again slowly."
        default: return model.store.samples.isEmpty ? "We did not hear you. Check the microphone." : "Keep going, every try helps."
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(model.melody.title).font(.headline).foregroundStyle(.white.opacity(0.7))
                ScoreRingView(score: model.result.score)
                StarRatingView(stars: model.result.stars, animated: true)
                Text(message).font(.title3.bold()).foregroundStyle(.white).multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    statRow("Time in tune", "\(Int(model.result.inTunePercent.rounded()))%")
                    statRow("Average off-pitch", "\(Int(model.result.averageCentsOff.rounded())) cents")
                    if let best = model.previousBest {
                        let delta = model.result.score - best
                        statRow("Personal best", delta > 0 ? "New best! +\(delta)" : "\(best)")
                    } else {
                        statRow("Personal best", "First attempt")
                    }
                }
                .glowCard()

                HStack {
                    Button("Try again", action: onRetry).buttonStyle(.bordered).accessibilityIdentifier("tryAgain")
                    Button("Done", action: onDone).buttonStyle(.borderedProminent).accessibilityIdentifier("doneResults")
                }
                .controlSize(.large)
            }
            .padding()
        }
        .sensoryFeedback(.success, trigger: model.result.stars)
        .preferredColorScheme(.dark)
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).bold()
        }
    }
}
