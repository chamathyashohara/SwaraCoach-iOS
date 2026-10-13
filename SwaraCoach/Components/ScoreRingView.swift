import SwiftUI

/// Circular score indicator whose number counts up from 0.
struct ScoreRingView: View {
    let score: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric private var size: CGFloat = 180
    @State private var shown = 0.0

    var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 16)
            Circle()
                .trim(from: 0, to: shown / 100)
                .stroke(Theme.brand, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(shown))")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .contentTransition(.numericText(value: shown))
                Text("out of 100").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(score) out of 100")
        .accessibilityIdentifier("scoreLabel")
        .onAppear {
            if reduceMotion { shown = Double(score) } else { withAnimation(.easeOut(duration: 1.2)) { shown = Double(score) } }
        }
    }
}
