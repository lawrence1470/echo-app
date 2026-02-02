import SwiftUI

/// A text view with an animated shimmer gradient sweep, matching the Expo ShimmeringText component.
struct ShimmeringText: View {
    let text: String
    var fontSize: CGFloat = 14
    var color: Color = NColor.ash
    var shimmerColor: Color = NColor.charcoal
    var duration: Double = 1.6

    @State private var phase: CGFloat = 0

    var body: some View {
        Text(text)
            .font(NFont.spaceGrotesk(fontSize, weight: .medium))
            .foregroundStyle(
                LinearGradient(
                    colors: [color, shimmerColor, color],
                    startPoint: UnitPoint(x: phase - 0.5, y: 0.5),
                    endPoint: UnitPoint(x: phase + 0.5, y: 0.5)
                )
            )
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 2.0
                }
            }
    }
}
