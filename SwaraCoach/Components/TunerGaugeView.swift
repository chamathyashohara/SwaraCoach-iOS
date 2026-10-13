import SwiftUI

/// Custom half-circle gauge with a needle that springs to the measured pitch error (cents, -50...+50).
struct TunerGaugeView: View {
    let cents: Double
    let active: Bool
    @ScaledMetric private var height: CGFloat = 170
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clamped: Double { max(-50, min(50, cents)) }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let radius = min(width / 2 - 8, proxy.size.height - 12)
            let centre = CGPoint(x: width / 2, y: proxy.size.height - 6)
            let needleLength = radius - 14
            ZStack {
                // Coloured scale, drawn as bands from the left edge to the right edge (angles from straight up).
                band(-90, -45, centre, radius, Theme.off)
                band(-45, -22.5, centre, radius, Theme.close)
                band(-22.5, 22.5, centre, radius, Theme.inTune)
                band(22.5, 45, centre, radius, Theme.close)
                band(45, 90, centre, radius, Theme.off)

                // Needle: a line from the pivot straight up, rotated about the pivot (+-45 degrees for +-50 cents).
                Path { path in
                    path.move(to: centre)
                    path.addLine(to: CGPoint(x: centre.x, y: centre.y - needleLength))
                }
                .stroke(active ? Color.primary : Color.secondary.opacity(0.4),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(clamped * 0.9), anchor: UnitPoint(x: 0.5, y: centre.y / max(1, proxy.size.height)))
                .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.6), value: clamped)

                Circle().fill(Color.primary).frame(width: 14, height: 14).position(centre)
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tuner gauge")
        .accessibilityValue(active ? "\(Int(cents.rounded())) cents, \(Theme.word(forCents: cents))" : "No note detected")
    }

    /// An arc drawn as a short polyline, so there is no ambiguity about arc direction.
    /// Angles are in degrees from straight up, positive to the right.
    private func band(_ from: Double, _ to: Double, _ centre: CGPoint, _ radius: CGFloat, _ colour: Color) -> some View {
        Path { path in
            var angle = from
            while angle <= to + 0.001 {
                let radians = angle * .pi / 180
                let point = CGPoint(x: centre.x + radius * CGFloat(sin(radians)), y: centre.y - radius * CGFloat(cos(radians)))
                if angle == from { path.move(to: point) } else { path.addLine(to: point) }
                angle += 2
            }
        }
        .stroke(colour, style: StrokeStyle(lineWidth: 12, lineCap: .butt))
    }
}
