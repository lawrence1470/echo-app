import SwiftUI
import CoreText

/// Registers bundled Space Grotesk fonts from the SPM resource bundle.
/// Call once at app launch.
public func registerCustomFonts() {
    let fontNames = [
        "SpaceGrotesk-Regular",
        "SpaceGrotesk-Medium",
        "SpaceGrotesk-SemiBold",
        "SpaceGrotesk-Bold",
    ]

    for name in fontNames {
        guard let url = Bundle.module.url(forResource: name, withExtension: "ttf") else {
            print("[Fonts] Missing font file: \(name).ttf")
            continue
        }
        guard let data = try? Data(contentsOf: url) as CFData,
              let provider = CGDataProvider(data: data),
              let font = CGFont(provider) else {
            print("[Fonts] Failed to load font: \(name)")
            continue
        }
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterGraphicsFont(font, &error) {
            let desc = error?.takeRetainedValue().localizedDescription ?? "unknown"
            print("[Fonts] Failed to register \(name): \(desc)")
        }
    }
}

// MARK: - Font helpers

enum NFont {
    static func spaceGrotesk(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .bold:
            .custom("SpaceGrotesk-Bold", size: size)
        case .semibold:
            .custom("SpaceGrotesk-SemiBold", size: size)
        case .medium:
            .custom("SpaceGrotesk-Medium", size: size)
        default:
            .custom("SpaceGrotesk-Regular", size: size)
        }
    }
}
