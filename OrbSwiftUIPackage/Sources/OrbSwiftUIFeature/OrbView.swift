import SwiftUI
#if canImport(CoreMotion)
import CoreMotion
#endif

// MARK: - Orb Stage

enum OrbStage: String, CaseIterable {
    case idle
    case transcribing
    case thinking
    case complete

    var numericValue: Float {
        switch self {
        case .idle: 0
        case .transcribing: 1
        case .thinking: 2
        case .complete: 3
        }
    }

    var transitionDuration: Double {
        switch self {
        case .idle: 0.5
        case .transcribing: 0.25
        case .thinking: 0.35
        case .complete: 0.3
        }
    }
}

// MARK: - Motion Manager

@Observable
@MainActor
final class OrbMotionManager {
    var tiltX: Float = 0
    var tiltY: Float = 0

    #if canImport(CoreMotion)
    private let motionManager = CMMotionManager()
    #endif

    func start() {
        #if canImport(CoreMotion)
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 1.0 / 30.0

        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let newX = Float(max(-1, min(1, data.acceleration.x)))
            let newY = Float(max(-1, min(1, data.acceleration.y)))
            self.tiltX += (newX - self.tiltX) * 0.15
            self.tiltY += (newY - self.tiltY) * 0.15
        }
        #endif
    }

    func stop() {
        #if canImport(CoreMotion)
        motionManager.stopAccelerometerUpdates()
        #endif
    }
}

// MARK: - Orb View

struct OrbView: View {
    var intensity: Float = 0
    var size: CGFloat = 250
    var isRecording: Bool = false
    var stage: OrbStage = .idle

    @State private var motionManager = OrbMotionManager()
    @State private var animatedStage: Float = 0
    @State private var stageProgress: Float = 1
    @State private var startDate = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = Float(timeline.date.timeIntervalSince(startDate))

            Rectangle()
                .fill(.white)
                .frame(width: size, height: size)
                .colorEffect(
                    ShaderLibrary.orbShader(
                        .float2(Float(size), Float(size)),
                        .float(time),
                        .float(intensity),
                        .float(isRecording ? 1.0 : 0.0),
                        .float(animatedStage),
                        .float(stageProgress),
                        .float2(motionManager.tiltX, motionManager.tiltY)
                    )
                )
        }
        .shadow(color: Color(white: 0.1, opacity: 0.25), radius: 20, y: 4)
        .onChange(of: stage) { _, newStage in
            withAnimation(.easeInOut(duration: newStage.transitionDuration)) {
                animatedStage = newStage.numericValue
            }
            stageProgress = 0
            withAnimation(.easeOut(duration: newStage.transitionDuration)) {
                stageProgress = 1
            }
        }
        .onAppear {
            animatedStage = stage.numericValue
            motionManager.start()
        }
        .onDisappear {
            motionManager.stop()
        }
    }
}

// MARK: - Preview

#Preview("Orb - Idle") {
    ZStack {
        Color(white: 0.97)
            .ignoresSafeArea()
        OrbView()
    }
}

#Preview("Orb - Recording") {
    ZStack {
        Color(white: 0.97)
            .ignoresSafeArea()
        OrbView(intensity: 0.6, isRecording: true, stage: .transcribing)
    }
}

#Preview("Orb - Interactive") {
    OrbDemoView()
}

// MARK: - Demo View (for testing all states)

struct OrbDemoView: View {
    @State private var stage: OrbStage = .idle
    @State private var intensity: Float = 0
    @State private var isRecording = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            OrbView(
                intensity: intensity,
                size: 280,
                isRecording: isRecording,
                stage: stage
            )

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    ForEach(OrbStage.allCases, id: \.self) { s in
                        Button(s.rawValue.capitalized) {
                            stage = s
                            isRecording = (s == .transcribing)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(stage == s ? .primary : .secondary)
                    }
                }

                HStack {
                    Text("Intensity")
                    Slider(value: $intensity, in: 0...1)
                }
                .padding(.horizontal, 32)
            }

            Spacer()
        }
        .background(Color(white: 0.97))
    }
}
