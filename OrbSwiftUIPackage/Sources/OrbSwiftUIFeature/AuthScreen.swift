import SwiftUI

struct AuthScreen: View {
    @Environment(AuthService.self) private var authService
    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var navigateToVerify = false

    var body: some View {
        NavigationStack {
            ZStack {
                NColor.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Header
                    VStack(alignment: .leading, spacing: NSpacing.xs) {
                        Text("Welcome")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(NColor.text)

                        Text("Enter your email and we'll send you a one-time code to sign in")
                            .font(.system(size: 18))
                            .foregroundStyle(NColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, NSpacing.xxl)

                    // Form
                    VStack(alignment: .leading, spacing: NSpacing.md) {
                        VStack(alignment: .leading, spacing: NSpacing.xs) {
                            Text("Email")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(NColor.textSecondary)

                            TextField("you@example.com", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(size: 16))
                                .foregroundStyle(NColor.text)
                                .padding(NSpacing.md)
                                .background(NColor.card)
                                .overlay(
                                    RoundedRectangle(cornerRadius: NRadius.md)
                                        .stroke(NColor.border, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: NRadius.md))
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundStyle(.red)
                        }

                        Button {
                            Task { await sendCode() }
                        } label: {
                            Group {
                                if isLoading {
                                    ProgressView()
                                        .tint(NColor.buttonPrimaryFg)
                                } else {
                                    Text("Send OTP")
                                }
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(NColor.buttonPrimaryFg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(email.isEmpty ? NColor.ash : NColor.buttonPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: NRadius.md))
                        }
                        .disabled(email.isEmpty || isLoading)
                    }

                    Spacer()
                }
                .padding(.horizontal, NSpacing.lg)
            }
            .navigationDestination(isPresented: $navigateToVerify) {
                VerifyOTPScreen(email: email)
            }
        }
    }

    private func sendCode() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await authService.sendOTP(email: email)
            navigateToVerify = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
