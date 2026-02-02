import SwiftUI

struct SpeechInputRecordButton: View {
    let isRecording: Bool
    let isTranscribing: Bool
    let onTap: () -> Void

    @State private var isPulsing = false

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            onTap()
        }) {
            ZStack {
                if isTranscribing {
                    ProgressView()
                        .tint(NColor.graphite)
                } else if isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(NColor.void_)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(NColor.void_)
                }
            }
            .frame(width: 64, height: 64)
            .background(isTranscribing ? NColor.gray200 : .white)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
            .scaleEffect(isPulsing ? 1.05 : 1.0)
        }
        .disabled(isTranscribing)
        .onChange(of: isRecording) { _, recording in
            if recording {
                withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.15)) {
                    isPulsing = false
                }
            }
        }
    }
}
