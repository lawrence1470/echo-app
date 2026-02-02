import Foundation
import Supabase

// MARK: - Response Types

public struct ProcessEntryResponse: Codable, Sendable {
    public let title: String
    public let sentiment: Sentiment

    public struct Sentiment: Codable, Sendable {
        public let score: Double
        public let label: String
        public let emotions: [Emotion]?

        public struct Emotion: Codable, Sendable {
            public let emotion: String
            public let confidence: Double
        }
    }
}

public struct TranscriptionResponse: Codable, Sendable {
    public let transcription: String
}

public struct FollowUpResponse: Codable, Sendable {
    public let followUpQuestion: String
}

public struct InsightResponse: Codable, Sendable {
    public let insight: String
}

// MARK: - Edge Function Service

@Observable
@MainActor
public final class EdgeFunctionService {

    public init() {}

    // MARK: - Transcribe Audio

    /// Uploads an audio file to the `transcribe-audio` edge function.
    public func transcribeAudio(fileURL: URL) async throws -> TranscriptionResponse {
        let data = try Data(contentsOf: fileURL)
        let boundary = UUID().uuidString

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"audio.m4a\"\r\n")
        body.append("Content-Type: audio/m4a\r\n\r\n")
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n")

        let session = try await supabase.auth.session
        let url = URL(string: "https://smyoggxvfhlcjleqhnvg.supabase.co/functions/v1/transcribe-audio")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (responseData, httpResponse) = try await URLSession.shared.data(for: request)

        if let httpResponse = httpResponse as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let bodyString = String(data: responseData, encoding: .utf8) ?? "no body"
            throw EdgeFunctionError.serverError(statusCode: httpResponse.statusCode, body: bodyString)
        }

        return try JSONDecoder().decode(TranscriptionResponse.self, from: responseData)
    }

    // MARK: - Process Entry

    public func processEntry(transcription: String) async throws -> ProcessEntryResponse {
        try await supabase.functions.invoke(
            "process-entry",
            options: .init(body: ["transcription": transcription])
        )
    }

    // MARK: - Generate Follow-Up

    public func generateFollowUp(
        transcription: String,
        title: String,
        sentiment: String
    ) async throws -> FollowUpResponse {
        try await supabase.functions.invoke(
            "generate-followup",
            options: .init(body: [
                "transcription": transcription,
                "title": title,
                "sentiment": sentiment,
            ])
        )
    }

    // MARK: - Generate Insight

    public func generateInsight() async throws -> InsightResponse {
        try await supabase.functions.invoke(
            "generate-insight",
            options: .init(body: [:] as [String: String])
        )
    }
}

// MARK: - Error Type

public enum EdgeFunctionError: LocalizedError {
    case serverError(statusCode: Int, body: String)

    public var errorDescription: String? {
        switch self {
        case .serverError(let statusCode, let body):
            "Server error (\(statusCode)): \(body)"
        }
    }
}

// MARK: - Data helpers

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
