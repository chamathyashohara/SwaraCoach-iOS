import SwiftUI

/// Central place for the brand colours and shared sizes (theming).
enum Theme {
    static let brand = Color(red: 0.416, green: 0.247, blue: 0.847)        // #6A3FD8
    static let brandLight = Color(red: 0.718, green: 0.612, blue: 1.0)     // #B79CFF
    static let stage = Color(red: 0.082, green: 0.071, blue: 0.145)        // sing screen background
    static let inTune = Color(red: 0.298, green: 0.765, blue: 0.541)       // within 25 cents
    static let close = Color(red: 0.961, green: 0.706, blue: 0.290)        // within 50 cents
    static let off = Color(red: 1.0, green: 0.42, blue: 0.322)             // further away

    static let cornerRadius: CGFloat = 16

    /// Colour for a pitch error. Always shown together with text, never colour alone.
    static func color(forCents cents: Double) -> Color {
        let error = abs(cents)
        return error <= 25 ? inTune : error <= 50 ? close : off
    }

    static func word(forCents cents: Double) -> String {
        if abs(cents) <= 10 { return "in tune" }
        return cents < 0 ? "flat" : "sharp"
    }
}
