import Foundation

struct AIAnswerRequest: Encodable {
    struct Evidence: Encodable {
        let document_title: String
        let page: Int
        let excerpt: String
    }

    let question: String
    let evidence: [Evidence]
}

struct AIAnswerResponse: Decodable {
    let answer: String
    let model: String
}

enum LifePilotAIError: LocalizedError {
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The AI server returned an invalid response."
        case .serverError(let message):
            return message
        }
    }
}

struct LifePilotAIService {
    // For the iOS Simulator, the Mac's localhost is reachable here.
    private let baseURL = URL(string: "http://127.0.0.1:8000")!

    func answer(
        question: String,
        evidence: [AIAnswerRequest.Evidence]
    ) async throws -> AIAnswerResponse {
        let url = baseURL.appendingPathComponent("v1/answer")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            AIAnswerRequest(question: question, evidence: evidence)
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LifePilotAIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let error = try? JSONDecoder().decode(
                ServerErrorResponse.self,
                from: data
            ) {
                throw LifePilotAIError.serverError(error.detail)
            }

            throw LifePilotAIError.serverError(
                "AI server error (HTTP \(httpResponse.statusCode))."
            )
        }

        return try JSONDecoder().decode(AIAnswerResponse.self, from: data)
    }
}

private struct ServerErrorResponse: Decodable {
    let detail: String
}
