import SwiftUI

/// Animates text word-by-word with a fade-in effect, matching the Expo TypewriterText component.
struct TypewriterText: View {
    let text: String
    var wordDelay: Duration = .milliseconds(50)
    var onComplete: (() -> Void)?

    @State private var visibleCount = 0

    private var words: [String] {
        text.split(separator: " ").map(String.init)
    }

    var body: some View {
        // Use a FlowLayout-like wrapping text by building an AttributedString
        // with opacity per word, or simpler: just show a substring
        Text(visibleText)
            .font(NFont.spaceGrotesk(16))
            .foregroundStyle(NColor.ink)
            .lineSpacing(6)
            .tracking(0.2)
            .multilineTextAlignment(.center)
            .animation(.easeIn(duration: 0.12), value: visibleCount)
            .task(id: text) {
                visibleCount = 0
                let wordList = words
                for i in 1...wordList.count {
                    guard !Task.isCancelled else { return }
                    try? await Task.sleep(for: wordDelay)
                    visibleCount = i
                }
                onComplete?()
            }
    }

    private var visibleText: String {
        words.prefix(visibleCount).joined(separator: " ")
    }
}
