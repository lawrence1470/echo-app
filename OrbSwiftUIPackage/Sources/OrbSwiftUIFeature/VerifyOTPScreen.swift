import SwiftUI

struct VerifyOTPScreen: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss

    let email: String

    @State private var code = ""
    @State private var isVerifying = false
    @State private var isResending = false
    @State private var errorMessage: String?
    @FocusState private var codeFocused: Bool

    var body: some View {
        ZStack {
            NColor.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: NSpacing.sm) {
                    Text("Enter code")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(NColor.text)

                    Text("We sent a 6-digit code to\n")
                        .font(.system(size: 16))
                        .foregroundStyle(NColor.textSecondary)
                    +
                    Text(email)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(NColor.text)
                }
                .padding(.top, NSpacing.xxl)

                // OTP Input
                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { index in
                        let digit = index < code.count
                            ? String(code[code.index(code.startIndex, offsetBy: index)])
                            : ""

                        Text(digit)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(NColor.text)
                            .frame(width: 48, height: 56)
                            .background(digit.isEmpty ? NColor.card : NColor.background)
                            .overlay(
                                RoundedRectangle(cornerRadius: NRadius.md)
                                    .stroke(
                                        index == code.count ? NColor.gray800 : NColor.border,
                                        lineWidth: index == code.count ? 2 : 1
                                    )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: NRadius.md))
                    }
                }
                .padding(.top, NSpacing.xl)
                .overlay {
                    // Hidden text field to capture keyboard input
                    TextField("", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($codeFocused)
                        .opacity(0.01)
                        .onChange(of: code) { _, newValue in
                            // Limit to 6 digits
                            if newValue.count > 6 {
                                code = String(newValue.prefix(6))
                            }
                            // Filter non-digits
                            code = code.filter(\.isNumber)
                            // Auto-verify when 6 digits entered
                            if code.count == 6 {
                                Task { await verify() }
                            }
                        }
                }
                .onTapGesture { codeFocused = true }
                .onAppear { codeFocused = true }

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .padding(.top, NSpacing.sm)
                }

                // Verify button
                Button {
                    Task { await verify() }
                } label: {
                    Group {
                        if isVerifying {
                            ProgressView()
                                .tint(NColor.buttonPrimaryFg)
                        } else {
                            Text("Verify")
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NColor.buttonPrimaryFg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(code.count != 6 ? NColor.ash : NColor.buttonPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: NRadius.md))
                }
                .disabled(code.count != 6 || isVerifying)
                .padding(.top, NSpacing.lg)

                // Resend
                Button {
                    Task { await resend() }
                } label: {
                    Text(isResending ? "Sending..." : "Didn't get the code? Resend")
                        .font(.system(size: 16))
                        .foregroundStyle(NColor.textSecondary)
                        .frame(maxWidth: .infinity)
                }
                .disabled(isResending)
                .padding(.top, NSpacing.xl)

                Spacer()
            }
            .padding(.horizontal, NSpacing.lg)
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18))
                        .foregroundStyle(NColor.text)
                }
            }
        }
    }

    private func verify() async {
        guard code.count == 6 else { return }
        errorMessage = nil
        isVerifying = true
        defer { isVerifying = false }

        do {
            try await authService.verifyOTP(email: email, code: code)
            // AuthService will detect the session change and the root view will switch automatically
        } catch {
            errorMessage = error.localizedDescription
            code = ""
        }
    }

    private func resend() async {
        isResending = true
        defer { isResending = false }

        do {
            try await authService.sendOTP(email: email)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
