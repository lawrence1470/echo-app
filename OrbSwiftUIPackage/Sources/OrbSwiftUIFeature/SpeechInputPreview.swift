import SwiftUI

struct SpeechInputPreview: View {
    let isRecording: Bool
    let duration: TimeInterval

    private var timeString: String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: NSpacing.xs) {
            Text(timeString)
                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                .foregroundStyle(NColor.text)
                .contentTransition(.numericText())

            Text("Recording...")
                .font(.system(size: 16))
                .foregroundStyle(NColor.textMuted)
        }
        .opacity(isRecording ? 1 : 0)
        .scaleEffect(isRecording ? 1 : 0.9)
        .animation(.easeOut(duration: isRecording ? 0.2 : 0.15), value: isRecording)
    }
}
