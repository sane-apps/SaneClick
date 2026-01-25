import SwiftUI

// MARK: - Sane Apps Brand Colors
// Reference: ~/SaneApps/meta/Brand/SaneApps-Brand-Guidelines.md

extension Color {
    // MARK: - Brand Colors (Primary)

    /// Navy - Logo background, dark surfaces
    static let saneNavy = Color(red: 0.102, green: 0.153, blue: 0.267) // #1a2744

    /// Deep Navy - Gradient endpoint, deepest darks
    static let saneDeepNavy = Color(red: 0.051, green: 0.082, blue: 0.145) // #0d1525

    /// Glowing Teal - Logo accent, highlights, CTAs
    static let saneTeal = Color(red: 0.373, green: 0.659, blue: 0.827) // #5fa8d3

    /// Silver - Secondary elements, borders
    static let saneSilver = Color(red: 0.659, green: 0.706, blue: 0.769) // #a8b4c4

    // MARK: - Surface Colors

    /// Void - Backgrounds
    static let saneVoid = Color(red: 0.039, green: 0.039, blue: 0.039) // #0a0a0a

    /// Carbon - Cards, elevated surfaces
    static let saneCarbon = Color(red: 0.078, green: 0.078, blue: 0.078) // #141414

    /// Smoke - Borders, dividers
    static let saneSmoke = Color(red: 0.133, green: 0.133, blue: 0.133) // #222222

    /// Stone - Muted text
    static let saneStone = Color(red: 0.533, green: 0.533, blue: 0.533) // #888888

    /// Cloud - Primary text
    static let saneCloud = Color(red: 0.898, green: 0.898, blue: 0.898) // #e5e5e5

    // MARK: - App Accent (SaneScript)

    /// SaneScript accent - Terminal teal (matches brand teal)
    static let saneAccent = Color(red: 0.373, green: 0.659, blue: 0.827) // #5fa8d3

    // MARK: - Semantic Colors

    /// Success - Confirmations, active states
    static let saneSuccess = Color(red: 0.133, green: 0.773, blue: 0.369) // #22c55e

    /// Warning - Caution states
    static let saneWarning = Color(red: 0.961, green: 0.620, blue: 0.043) // #f59e0b

    /// Error - Error states
    static let saneError = Color(red: 0.937, green: 0.267, blue: 0.267) // #ef4444
}
