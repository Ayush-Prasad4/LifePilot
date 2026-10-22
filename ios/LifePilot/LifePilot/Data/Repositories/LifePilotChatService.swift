import Foundation

struct LifePilotChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    struct TaskContext: Encodable {
        let id: String
        let title: String
        let dueDate: String
        let priority: String
        let isCompleted: Bool
    }

    let message: String
    let history: [Message]
    let tasks: [TaskContext]
}

struct LifePilotChatResponse: Decodable {
    let answer: String
    let model: String
}

struct LifePilotTaskActionProposal: Decodable, Identifiable {
    let action: String
    let task_id: String?
    let title: String?
    let dueDate: String?
    let priority: String?

    var id: String {
        "\\(action)-\\(task_id ?? title ?? UUID().uuidString)"
    }

    var summary: String {
        let taskTitle = title ?? "Untitled task"
        let taskID = task_id ?? "unknown"

        switch action {
        case "create":
            return "Create task: " + taskTitle
        case "edit":
            return "Edit task: " + (title ?? "Update requested fields")
        case "complete":
            return "Mark task complete (ID: " + taskID + ")"
        case "delete":
            return "Delete task (ID: " + taskID + ")"
        default:
            return "Unknown action"
        }
    }
}

private struct LifePilotTaskActionsRequest: Encodable {
    let message: String
    let tasks: [LifePilotChatRequest.TaskContext]
}

private struct LifePilotTaskActionsResponse: Decodable {
    let proposals: [LifePilotTaskActionProposal]
    let model: String
}

struct LifePilotChatService {
    func proposeTaskActions(
        message: String,
        tasks: [PlannerTask]
    ) async throws -> [LifePilotTaskActionProposal] {
        let baseURL = try LifePilotAPIConfiguration.baseURL()
        var request = URLRequest(
            url: baseURL.appendingPathComponent("v1/chat/actions")
        )
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let taskContexts = tasks.prefix(100).map { task in
            LifePilotChatRequest.TaskContext(
                id: task.id.uuidString,
                title: task.title,
                dueDate: ISO8601DateFormatter().string(from: task.dueDate),
                priority: task.priority.rawValue,
                isCompleted: task.isCompleted
            )
        }
        request.httpBody = try JSONEncoder().encode(
            LifePilotTaskActionsRequest(message: message, tasks: taskContexts)
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LifePilotAIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            if let error = try? JSONDecoder().decode(ChatServerError.self, from: data) {
                throw LifePilotAIError.serverError(error.detail)
            }
            throw LifePilotAIError.serverError(
                "AI server error (HTTP \\(http.statusCode))."
            )
        }
        return try JSONDecoder().decode(
            LifePilotTaskActionsResponse.self, from: data
        ).proposals
    }

    func send(
        message: String,
        history: [LifePilotChatRequest.Message],
        tasks: [PlannerTask]
    ) async throws -> LifePilotChatResponse {
        let baseURL = try LifePilotAPIConfiguration.baseURL()
        var request = URLRequest(
            url: baseURL.appendingPathComponent("v1/chat")
        )
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            LifePilotChatRequest(
                message: message,
                history: Array(history.suffix(10)),
                tasks: tasks.prefix(100).map { task in
                    LifePilotChatRequest.TaskContext(
                        id: task.id.uuidString,
                        title: task.title,
                        dueDate: ISO8601DateFormatter().string(from: task.dueDate),
                        priority: task.priority.rawValue,
                        isCompleted: task.isCompleted
                    )
                }
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
