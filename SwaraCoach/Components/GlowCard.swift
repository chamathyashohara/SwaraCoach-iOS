import SwiftUI

/// Custom view modifier: rounded card with a soft brand-coloured glow in Dark Mode.
struct GlowCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: colorScheme == .dark ? Theme.brand.opacity(0.45) : Color.black.opacity(0.08),
                            radius: colorScheme == .dark ? 10 : 6, y: 2)
            )
    }
}

extension View {
    func glowCard(padding: CGFloat = 16) -> some View { modifier(GlowCard(padding: padding)) }
}
