import SwiftUI

struct ScrubBar: View {
    let duration: TimeInterval   // target duration in seconds
    let currentTime: TimeInterval // elapsed time in seconds

    private var progress: Double {
        guard duration > 0 else { return 0 }
        return min(currentTime / duration, 1)
    }

    var body: some View {
        VStack(spacing: NSpacing.xs) {
            // Track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(NColor.gray200)
                        .frame(height: 8)

                    // Filled portion
                    RoundedRectangle(cornerRadius: 4)
                        .fill(NColor.gray800)
                        .frame(width: geo.size.width * progress, height: 8)
                        .animation(.spring(response: 0.4), value: progress)
                }
            }
            .frame(height: 8)

            // Time labels
            HStack {
                Text(formatTime(currentTime))
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(NColor.gray500)

                Spacer()

                Text(formatTime(duration))
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(NColor.gray500)
            }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
