import Foundation

struct LifePilotChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let message: String
    let history: [Message]
}

struct LifePilotChatResponse: Decodable {
    let answer: String
    let model: String
}

struct LifePilotChatService {
    private let baseURL = URL(string: "http://127.0.0.1:8000")!

    func send(
        message: String,
        history: [LifePilotChatRequest.Message]
    ) async throws -> LifePilotChatResponse {
        var request = URLRequest(
            url: baseURL.appendingPathComponent("v1/chat")
        )
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            LifePilotChatRequest(
                message: message,
                history: Array(history.suffix(10))
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LifePilotAIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            if let error = try? JSONDecoder().decode(
                ChatServerError.self, from: data
            ) {
                throw LifePilotAIError.serverError(error.detail)
            }
            throw LifePilotAIError.serverError(
                "AI server error (HTTP \(http.statusCode))."
            )
        }
        return try JSONDecoder().decode(LifePilotChatResponse.self, from: data)
    }
}

private struct ChatServerError: Decodable {
    let detail: String
}
