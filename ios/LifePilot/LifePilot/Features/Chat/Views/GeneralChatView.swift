import SwiftUI

struct LifePilotChatMessage: Identifiable, Codable, Equatable {
    enum Role: String, Codable {
        case user
        case assistant
    }

    var id = UUID()
    var role: Role
    var content: String
    var createdAt = Date()
}

struct LifePilotConversation: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var messages: [LifePilotChatMessage] = []
    var updatedAt = Date()
}

struct LifePilotConversationStore {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "lifepilot.chat.conversations"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func load() -> [LifePilotConversation] {
        loadIfValid() ?? []
    }

    func loadIfValid() -> [LifePilotConversation]? {
        guard let data = defaults.data(forKey: key) else { return [] }
        return try? JSONDecoder().decode(
            [LifePilotConversation].self, from: data
        )
    }

    @discardableResult
    func save(_ conversations: [LifePilotConversation]) -> Bool {
        // Preserve existing data if it is present but cannot be decoded.
        if defaults.data(forKey: key) != nil, loadIfValid() == nil {
            return false
        }

        guard let data = try? JSONEncoder().encode(conversations) else {
            return false
        }

        defaults.set(data, forKey: key)
        return true
    }
}

struct GeneralChatView: View {
    @State private var conversations = LifePilotConversationStore().load()
    @State private var selectedID: UUID?
    @State private var draft = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var pendingActionProposals: [LifePilotTaskActionProposal] = []
    @State private var showActionPreview = false
    @FocusState private var composerFocused: Bool

    private let store = LifePilotConversationStore()
    private let service = LifePilotChatService()

    private var selectedIndex: Int? {
        conversations.firstIndex { $0.id == selectedID }
    }

    private var messages: [LifePilotChatMessage] {
        guard let index = selectedIndex else { return [] }
        return conversations[index].messages
    }

    var body: some View {
        VStack(spacing: 0) {
            if messages.isEmpty {
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 38))
                    .foregroundStyle(.tint)
                Text("What can I help with?")
                    .font(.title2.bold())
                    .padding(.top, 12)
                Text("Ask questions, brainstorm ideas, or work through a problem.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 4)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(messages) { message in
                                messageBubble(message)
                                    .id(message.id)
                            }

                            if isSending {
                                HStack {
                                    ProgressView()
                                    Text("Thinking…")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            composer
        }
        .navigationTitle(selectedConversationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button {
                        startNewChat()
                    } label: {
                        Label("New chat", systemImage: "plus")
                    }

                    if !conversations.isEmpty {
                        Divider()
                        ForEach(conversations) { conversation in
                            Button {
                                selectedID = conversation.id
                                errorMessage = nil
                            } label: {
                                if conversation.id == selectedID {
                                    Label(conversation.title, systemImage: "checkmark")
                                } else {
                                    Text(conversation.title)
                                }
                            }
                        }
                        Divider()
                        Button(role: .destructive) {
                            deleteSelectedChat()
                        } label: {
                            Label("Delete current chat", systemImage: "trash")
                        }
                        .disabled(selectedID == nil)
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                }
                .accessibilityLabel("Conversation history")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: startNewChat) {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("New chat")
            }
        }
        .onAppear {
            if store.loadIfValid() == nil {
                errorMessage = "Chat history could not be read. Existing conversation data was preserved."
            }

            if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset-tasks") {
                UserDefaults.standard.removeObject(forKey: "lifepilot.planner.tasks")
            }
            if ProcessInfo.processInfo.arguments.contains("-ui-testing-corrupt-task-storage") {
                UserDefaults.standard.set(
                    Data("invalid task data".utf8),
                    forKey: "lifepilot.planner.tasks"
                )
            }
            if selectedID == nil {
                selectedID = conversations.first?.id
            }
            if ProcessInfo.processInfo.arguments.contains("-ui-testing-invalid-action-preview") {
                pendingActionProposals = [
                    LifePilotTaskActionProposal(
                        action: "edit",
                        task_id: UUID().uuidString,
                        title: "Invalid Preview Test Task",
                        dueDate: nil,
                        priority: nil
                    )
                ]
                showActionPreview = true
            } else if ProcessInfo.processInfo.arguments.contains("-ui-testing-action-preview") {
                pendingActionProposals = [
                    LifePilotTaskActionProposal(
                        action: "create",
                        task_id: nil,
                        title: "Action Preview Test Task",
                        dueDate: nil,
                        priority: "Normal"
                    )
                ]
                showActionPreview = true
            }
        }
        .sheet(isPresented: $showActionPreview) {
            TaskActionPreviewSheet(
                proposals: pendingActionProposals,
                onConfirm: applyPendingActions,
                onCancel: {
                    pendingActionProposals = []
                }
            )
        }
    }

    private var selectedConversationTitle: String {
        guard let index = selectedIndex else { return "Chat" }
        return conversations[index].title
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message LifePilot…", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($composerFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 22))

            Button(action: sendMessage) {
                Image(systemName: "arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(canSend ? Color.accentColor : Color.gray)
                    .clipShape(Circle())
            }
            .disabled(!canSend)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSending
    }

    private func messageBubble(_ message: LifePilotChatMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 42) }

            Text(message.content)
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    message.role == .user
                        ? Color.accentColor
                        : Color(uiColor: .secondarySystemBackground)
                )
                .foregroundStyle(message.role == .user ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            if message.role == .assistant { Spacer(minLength: 28) }
        }
    }

    private func startNewChat() {
        let conversation = LifePilotConversation(title: "New chat")
        var updatedConversations = conversations
        updatedConversations.insert(conversation, at: 0)

        guard persist(updatedConversations) else { return }
        selectedID = conversation.id
    }

    private func deleteSelectedChat() {
        guard let id = selectedID else { return }

        var updatedConversations = conversations
        updatedConversations.removeAll { $0.id == id }

        guard persist(updatedConversations) else { return }
        selectedID = conversations.first?.id
    }

    @discardableResult
    private func persist(_ updatedConversations: [LifePilotConversation]) -> Bool {
        guard store.save(updatedConversations) else {
            errorMessage = "Could not save chat history. Existing conversation data was preserved."
            return false
        }

        conversations = updatedConversations
        errorMessage = nil
        return true
    }

    private func sendMessage() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        if selectedIndex == nil {
            startNewChat()
        }
        guard let index = selectedIndex else { return }

        let conversationID = conversations[index].id
        let history = conversations[index].messages.map {
            LifePilotChatRequest.Message(
                role: $0.role.rawValue,
                content: $0.content
            )
        }

        var updatedConversations = conversations
        updatedConversations[index].messages.append(
            LifePilotChatMessage(role: .user, content: text)
        )
        if updatedConversations[index].title == "New chat" {
            let title = text.replacingOccurrences(of: "\n", with: " ")
            updatedConversations[index].title = String(title.prefix(fortyCharacters))
        }
        updatedConversations[index].updatedAt = Date()

        guard persist(updatedConversations) else { return }
        draft = ""
        isSending = true

        Task {
            do {
                let currentTasks = CalendarTaskStore().load()

                if looksLikeCalendarAction(text) {
                    let proposals = try await service.proposeTaskActions(
                        message: text,
                        tasks: currentTasks
                    )
                    if !proposals.isEmpty {
                        pendingActionProposals = proposals
                        showActionPreview = true
                        appendAssistantMessage(
                            "I prepared \(proposals.count) calendar action(s). Review them and confirm before anything changes.",
                            conversationID: conversationID
                        )
                        isSending = false
                        return
                    }
                }

                let response = try await service.send(
                    message: text,
                    history: history,
                    tasks: currentTasks
                )
                appendAssistantMessage(
                    response.answer,
                    conversationID: conversationID
                )
            } catch {
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }

    private func looksLikeCalendarAction(_ text: String) -> Bool {
        let value = text.lowercased()
        let keywords = [
            "add task", "create task", "new task", "make a task",
            "schedule a task", "edit task", "update task", "change task",
            "rename task", "complete task", "finish task", "mark task",
            "delete task", "remove task", "cancel task"
        ]
        return keywords.contains { value.contains($0) }
    }

    private func appendAssistantMessage(
        _ content: String,
        conversationID: UUID
    ) {
        guard let currentIndex = conversations.firstIndex(
            where: { $0.id == conversationID }
        ) else { return }

        var updatedConversations = conversations
        updatedConversations[currentIndex].messages.append(
            LifePilotChatMessage(role: .assistant, content: content)
        )
        updatedConversations[currentIndex].updatedAt = Date()
        persist(updatedConversations)
    }

    private func applyPendingActions() {
        let store = CalendarTaskStore()
        var tasks = store.load()
        guard TaskActionProposalValidator.validate(
            pendingActionProposals,
            existingTasks: tasks
        ) else {
            errorMessage = "A proposed task changed or is invalid. Nothing was saved; please ask LifePilot to prepare the actions again."
            pendingActionProposals = []
            showActionPreview = false
            return
        }

        for proposal in pendingActionProposals {
            switch proposal.action {
            case "create":
                guard let rawTitle = proposal.title else { continue }
                let title = rawTitle.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                guard !title.isEmpty else { continue }
                let dueDate = parseProposalDate(proposal.dueDate)
                    ?? Calendar.current.startOfDay(for: Date())
                tasks.append(
                    PlannerTask(
                        title: title,
                        dueDate: dueDate,
                        priority: PlannerPriority(rawValue: proposal.priority ?? "") ?? .normal
                    )
                )

            case "edit":
                guard let idString = proposal.task_id,
                      let id = UUID(uuidString: idString),
                      let index = tasks.firstIndex(where: { $0.id == id }) else {
                    continue
                }
                if let title = proposal.title {
                    let cleanedTitle = title.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    if !cleanedTitle.isEmpty {
                        tasks[index].title = cleanedTitle
                    }
                }
                if let dateString = proposal.dueDate,
                   let date = parseProposalDate(dateString) {
                    tasks[index].dueDate = date
                }
                if let priorityString = proposal.priority,
                   let priority = PlannerPriority(rawValue: priorityString) {
                    tasks[index].priority = priority
                }

            case "complete":
                guard let idString = proposal.task_id,
                      let id = UUID(uuidString: idString),
                      let index = tasks.firstIndex(where: { $0.id == id }) else {
                    continue
                }
                tasks[index].isCompleted = true

            case "delete":
                guard let idString = proposal.task_id,
                      let id = UUID(uuidString: idString) else { continue }
                tasks.removeAll { $0.id == id }

            default:
                continue
            }
        }

        guard store.save(tasks) else {
            errorMessage = "Could not save calendar changes. Your existing task data was preserved."
            pendingActionProposals = []
            showActionPreview = false
            return
        }
        pendingActionProposals = []
        showActionPreview = false
    }

    private func parseProposalDate(_ value: String?) -> Date? {
        TaskActionProposalValidator.parseDate(value)
    }

    private let fortyCharacters = 40
}

private struct TaskActionPreviewSheet: View {
    let proposals: [LifePilotTaskActionProposal]
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Nothing changes until you confirm these actions.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section("Proposed changes") {
                    ForEach(proposals) { proposal in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(proposal.action.capitalized)
                                .font(.headline)
                            Text(proposal.summary)
                                .font(.subheadline)
                            if let dueDate = proposal.dueDate {
                                Text("Due: \\(dueDate)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let priority = proposal.priority {
                                Text("Priority: \\(priority)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Review actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        onConfirm()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
