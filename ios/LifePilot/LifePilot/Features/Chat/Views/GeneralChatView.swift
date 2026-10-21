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
        guard let data = defaults.data(forKey: key),
              let conversations = try? JSONDecoder().decode(
                [LifePilotConversation].self, from: data
              ) else { return [] }
        return conversations
    }

    func save(_ conversations: [LifePilotConversation]) {
        guard let data = try? JSONEncoder().encode(conversations) else { return }
        defaults.set(data, forKey: key)
    }
}

struct GeneralChatView: View {
    @State private var conversations = LifePilotConversationStore().load()
    @State private var selectedID: UUID?
    @State private var draft = ""
    @State private var isSending = false
    @State private var errorMessage: String?
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
            if selectedID == nil {
                selectedID = conversations.first?.id
            }
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
        conversations.insert(conversation, at: 0)
        selectedID = conversation.id
        errorMessage = nil
        persist()
    }

    private func deleteSelectedChat() {
        guard let id = selectedID else { return }
        conversations.removeAll { $0.id == id }
        selectedID = conversations.first?.id
        errorMessage = nil
        persist()
    }

    private func persist() {
        store.save(conversations)
    }

    private func sendMessage() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        if selectedIndex == nil {
            startNewChat()
        }
        guard let index = selectedIndex else { return }

        draft = ""
        errorMessage = nil

        let history = conversations[index].messages.map {
            LifePilotChatRequest.Message(
                role: $0.role.rawValue,
                content: $0.content
            )
        }

        conversations[index].messages.append(
            LifePilotChatMessage(role: .user, content: text)
        )
        if conversations[index].title == "New chat" {
            let title = text.replacingOccurrences(of: "\n", with: " ")
            conversations[index].title = String(title.prefix( fortyCharacters ))
        }
        conversations[index].updatedAt = Date()
        persist()
        isSending = true

        Task {
            do {
                let response = try await service.send(
                    message: text,
                    history: history,
                    tasks: CalendarTaskStore().load()
                )
                if let currentIndex = selectedIndex,
                   conversations[currentIndex].id == conversations[index].id {
                    conversations[currentIndex].messages.append(
                        LifePilotChatMessage(
                            role: .assistant,
                            content: response.answer
                        )
                    )
                    conversations[currentIndex].updatedAt = Date()
                    persist()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }

    private let fortyCharacters = 40
}
