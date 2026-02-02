import SwiftUI

// MARK: - Noir Design System (matches constants/theme.ts)

enum NColor {
    // Warm monochrome scale
    static let warmWhite = Color(hex: 0xF5F3F0)
    static let stone     = Color(hex: 0xE8E5E0)
    static let sand      = Color(hex: 0xD9D5CF)
    static let fogLight  = Color(hex: 0xC5C1BB)
    static let fog       = Color(hex: 0xB8B4AE)
    static let ash       = Color(hex: 0x8A8680)
    static let midGray   = Color(hex: 0x6B6866)
    static let graphite  = Color(hex: 0x5C5955)
    static let charcoal  = Color(hex: 0x3D3A37)
    static let ink       = Color(hex: 0x1A1918)
    static let void_     = Color(hex: 0x0A0A0A)

    // Semantic
    static let background      = stone
    static let text            = void_
    static let textSecondary   = ink
    static let textMuted       = graphite
    static let card            = warmWhite
    static let border          = sand
    static let buttonPrimary   = void_
    static let buttonPrimaryFg = warmWhite

    // Gray scale indexed
    static let gray50  = warmWhite
    static let gray100 = stone
    static let gray200 = sand
    static let gray300 = fogLight
    static let gray400 = ash
    static let gray500 = midGray
    static let gray800 = ink
    static let gray900 = void_
}

enum NSpacing {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
}

enum NRadius {
    static let sm:   CGFloat = 6
    static let md:   CGFloat = 10
    static let lg:   CGFloat = 14
    static let xl:   CGFloat = 18
    static let full: CGFloat = 9999
}

// MARK: - Color hex init

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
