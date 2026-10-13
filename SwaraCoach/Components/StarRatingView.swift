import SwiftUI

/// Shows 0...3 stars. With `animated`, the earned stars pop in one after another.
struct StarRatingView: View {
    let stars: Int
    var animated = false
    var font: Font = .title
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                let earned = index < (animated ? shown : stars)
                Image(systemName: earned ? "star.fill" : "star")
                    .foregroundStyle(earned ? Theme.close : Color.secondary)
                    .scaleEffect(earned ? 1 : 0.7)
                    .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.45), value: shown)
            }
        }
        .font(font)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stars) out of 3 stars")
        .task(id: stars) {
            guard animated else { return }
            shown = 0
            for next in 0..<stars {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 400))
                shown = next + 1
            }
        }
    }
}
