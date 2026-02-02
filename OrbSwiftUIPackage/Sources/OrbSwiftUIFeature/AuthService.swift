import Foundation
import Supabase
import Auth

private let supabaseBaseURL = "https://smyoggxvfhlcjleqhnvg.supabase.co"

@Observable
@MainActor
public final class AuthService {
    public var session: Session?
    public var user: User? { session?.user }
    public var isLoading = true

    nonisolated(unsafe) private var authStateTask: Task<Void, Never>?

    public init() {
        authStateTask = Task { [weak self] in
            // Fetch initial session
            do {
                self?.session = try await supabase.auth.session
            } catch {
                print("[AuthService] Session fetch error: \(error.localizedDescription)")
                self?.session = nil
            }
            self?.isLoading = false

            // Listen for auth state changes
            for await (event, session) in supabase.auth.authStateChanges {
                guard !Task.isCancelled else { break }
                switch event {
                case .signedIn, .tokenRefreshed:
                    self?.session = session
                case .signedOut:
                    self?.session = nil
                default:
                    break
                }
            }
        }
    }

    deinit {
        let task = authStateTask
        task?.cancel()
    }

    // MARK: - Custom OTP Flow (matches Expo send-otp / verify-otp edge functions)

    /// Calls the `send-otp` edge function to email a 6-digit code.
    public func sendOTP(email: String) async throws {
        let url = URL(string: "\(supabaseBaseURL)/functions/v1/send-otp")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["email": email])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthServiceError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let body = try? JSONDecoder().decode(ErrorBody.self, from: data)
            throw AuthServiceError.serverError(body?.error ?? "Failed to send code")
        }
    }

    /// Calls the `verify-otp` edge function, then uses the returned token to create a Supabase session.
    public func verifyOTP(email: String, code: String) async throws {
        // 1. Verify code with edge function
        let url = URL(string: "\(supabaseBaseURL)/functions/v1/verify-otp")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["email": email, "code": code])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthServiceError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let body = try? JSONDecoder().decode(ErrorBody.self, from: data)
            throw AuthServiceError.serverError(body?.error ?? "Invalid code")
        }

        let verifyResponse = try JSONDecoder().decode(VerifyOTPResponse.self, from: data)

        guard let tokenHash = verifyResponse.token, !tokenHash.isEmpty else {
            throw AuthServiceError.serverError("No token received")
        }

        // 2. Exchange token_hash for a Supabase session
        try await supabase.auth.verifyOTP(tokenHash: tokenHash, type: .magiclink)
    }

    public func signOut() async throws {
        try await supabase.auth.signOut()
    }
}

// MARK: - Supporting Types

public enum AuthServiceError: LocalizedError {
    case invalidResponse
    case serverError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid server response"
        case .serverError(let message): message
        }
    }
}

private struct ErrorBody: Codable {
    let error: String?
}

private struct VerifyOTPResponse: Codable {
    let success: Bool?
    let message: String?
    let token: String?
}
