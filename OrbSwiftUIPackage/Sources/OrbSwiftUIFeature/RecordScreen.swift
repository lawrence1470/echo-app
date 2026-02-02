import SwiftUI

public struct RecordScreen: View {
    @State private var recorder = AudioRecorder()
    @State private var hasRequestedPermission = false
    @State private var edgeFunctions = EdgeFunctionService()
    @State private var orbResponse: String?
    @State private var transcription: String?
    @State private var errorMessage: String?
    @State private var processingStage: ProcessingStage = .idle

    enum ProcessingStage: Equatable {
        case idle
        case listening   // transcribing audio
        case thinking    // processing entry + generating followup
        case complete
    }
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService

    public init() {}

    // Target session duration (5 min default)
    private let targetDuration: TimeInterval = 5 * 60

    private var orbStage: OrbStage {
        if recorder.isRecording { return .transcribing }
        switch processingStage {
        case .idle: return .idle
        case .listening: return .transcribing
        case .thinking: return .thinking
        case .complete: return .complete
        }
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                NColor.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: - Header
                    header

                    // MARK: - Content area
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: geo.size.height * 0.05)

                        OrbView(intensity: recorder.intensity, size: 280, isRecording: recorder.isRecording, stage: orbStage)
                            .frame(width: 280, height: 280)

                        Spacer()
                            .frame(height: NSpacing.xl)

                        // Prompt text / response / mic permission
                        if recorder.permissionGranted && !recorder.isRecording {
                            VStack(spacing: NSpacing.sm) {
                                switch processingStage {
                                case .listening:
                                    ShimmeringText(text: "Listening...")
                                        .transition(.opacity)
                                case .thinking:
                                    ShimmeringText(
                                        text: "Processing...",
                                        shimmerColor: NColor.ink
                                    )
                                    .transition(.opacity)
                                case .complete:
                                    if let error = errorMessage {
                                        ScrollView {
                                            Text(error)
                                                .font(.system(size: 12, design: .monospaced))
                                                .foregroundStyle(.red)
                                                .multilineTextAlignment(.leading)
                                        }
                                        .frame(maxHeight: 200)
                                        .padding(.horizontal, NSpacing.md)
                                    } else if let response = orbResponse {
                                        TypewriterText(text: response)
                                            .padding(.horizontal, NSpacing.lg)
                                        if let transcription {
                                            Text(transcription)
                                                .font(NFont.spaceGrotesk(14))
                                                .foregroundStyle(NColor.textMuted)
                                                .multilineTextAlignment(.center)
                                                .padding(.horizontal, NSpacing.lg)
                                                .lineLimit(3)
                                                .padding(.top, NSpacing.sm)
                                        }
                                    }
                                case .idle:
                                    Text("What's on your mind?")
                                        .font(NFont.spaceGrotesk(24, weight: .bold))
                                        .foregroundStyle(NColor.gray900)

                                    Text("Tap the button below to start recording")
                                        .font(NFont.spaceGrotesk(16))
                                        .foregroundStyle(NColor.textMuted)
                                }
                            }
                            .animation(.easeInOut(duration: 0.3), value: processingStage)
                        } else if !recorder.permissionGranted && !hasRequestedPermission {
                            micPermissionPrompt
                        }

                        Spacer()

                        // ScrubBar pinned to bottom of content
                        if recorder.permissionGranted {
                            ScrubBar(
                                duration: targetDuration,
                                currentTime: recorder.duration
                            )
                            .padding(.horizontal, NSpacing.xl)
                            .padding(.bottom, NSpacing.md)
                        }
                    }
                    .frame(maxHeight: .infinity)

                    // MARK: - Footer
                    if recorder.permissionGranted {
                        footer
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20))
                    .foregroundStyle(NColor.textMuted)
                    .frame(width: 40, height: 40)
            }

            Spacer()

            // Category chip placeholder
            Text("My Thoughts")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(NColor.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(NColor.gray200)
                .clipShape(Capsule())

            Spacer()

            // Sign out button
            Button("Sign Out") {
                Task { try? await authService.signOut() }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(NColor.textMuted)
        }
        .padding(.horizontal, NSpacing.md)
        .padding(.vertical, NSpacing.sm)
        .frame(minHeight: 56)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: NSpacing.md) {
            SpeechInputPreview(
                isRecording: recorder.isRecording,
                duration: recorder.duration
            )

            SpeechInputRecordButton(
                isRecording: recorder.isRecording,
                isTranscribing: recorder.isTranscribing,
                onTap: {
                    if recorder.isRecording {
                        recorder.stopRecording()
                        Task { await processRecording() }
                    } else {
                        orbResponse = nil
                        transcription = nil
                        errorMessage = nil
                        recorder.startRecording()
                    }
                }
            )
        }
        .padding(.top, NSpacing.md)
        .padding(.bottom, NSpacing.xxl)
    }

    // MARK: - Processing Pipeline

    private func processRecording() async {
        guard let fileURL = recorder.recordedFileURL else {
            errorMessage = "No recording found"
            processingStage = .complete
            recorder.finishTranscribing()
            return
        }

        processingStage = .listening

        do {
            // 1. Transcribe audio
            let transcribeResult = try await edgeFunctions.transcribeAudio(fileURL: fileURL)
            transcription = transcribeResult.transcription

            processingStage = .thinking

            // 2. Process entry for title + sentiment
            let processed = try await edgeFunctions.processEntry(transcription: transcribeResult.transcription)

            // 3. Generate follow-up question from the Orb
            do {
                let followUp = try await edgeFunctions.generateFollowUp(
                    transcription: transcribeResult.transcription,
                    title: processed.title,
                    sentiment: processed.sentiment.label
                )
                orbResponse = followUp.followUpQuestion
            } catch {
                orbResponse = processed.title
            }
        } catch {
            errorMessage = "\(error)"
        }

        processingStage = .complete
        recorder.finishTranscribing()
    }

    // MARK: - Mic Permission

    private var micPermissionPrompt: some View {
        VStack(spacing: NSpacing.md) {
            Image(systemName: "mic.slash")
                .font(.system(size: 40))
                .foregroundStyle(NColor.textMuted)

            Text("Microphone Access Required")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(NColor.text)

            Text("Echo needs microphone access to record your voice entries.")
                .font(.system(size: 16))
                .foregroundStyle(NColor.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, NSpacing.xl)

            Button {
                Task {
                    _ = await recorder.requestPermission()
                    hasRequestedPermission = true
                }
            } label: {
                Text("Enable Microphone")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NColor.buttonPrimaryFg)
                    .padding(.horizontal, NSpacing.lg)
                    .padding(.vertical, 12)
                    .background(NColor.buttonPrimary)
                    .clipShape(Capsule())
            }
        }
    }
}

#Preview {
    RecordScreen()
}
