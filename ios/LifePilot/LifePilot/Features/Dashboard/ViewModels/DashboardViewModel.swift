import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var searchText = ""
    @Published private(set) var tasks: [LifeTask] = []
    @Published private(set) var documents: [LifeDocument] = []
    @Published private(set) var totalTaskCount = 0
    @Published private(set) var completedTaskCount = 0
    @Published var selectedActionMessage: String?

    private let repository: any DashboardRepository
    private let useStoredDocuments: Bool
    private let useStoredTasks: Bool

    init(
        repository: (any DashboardRepository)? = nil,
        useStoredDocuments: Bool = true
    ) {
        let resolvedRepository = repository ?? DashboardService()
        self.repository = resolvedRepository
        self.useStoredDocuments = useStoredDocuments
        self.useStoredTasks = (repository == nil && useStoredDocuments)
        refreshTasks()
        documents = Self.loadDocuments(
            repository: resolvedRepository,
            useStoredDocuments: useStoredDocuments
        )
    }

    func refreshTasks() {
        guard useStoredTasks else {
            tasks = repository.fetchTasks()
            totalTaskCount = tasks.count
            completedTaskCount = 0
            return
        }

        let storedTasks = CalendarTaskStore().load()
        totalTaskCount = storedTasks.count
        completedTaskCount = storedTasks.filter(\.isCompleted).count

        tasks = storedTasks
            .filter { !$0.isCompleted }
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(3)
            .map { task in
                let dueLabel: String
                if Calendar.current.isDateInToday(task.dueDate) {
                    dueLabel = "Today · " + task.dueDate.formatted(date: .omitted, time: .shortened)
                } else if Calendar.current.isDateInTomorrow(task.dueDate) {
                    dueLabel = "Tomorrow · " + task.dueDate.formatted(date: .omitted, time: .shortened)
                } else {
                    dueLabel = task.dueDate.formatted(date: .abbreviated, time: .shortened)
                }

                return LifeTask(
                    id: task.id,
                    title: task.title,
                    subtitle: task.priority.rawValue + " priority",
                    dueLabel: dueLabel,
                    symbol: "calendar",
                    priority: task.priority == .normal ? .normal : .important
                )
            }
    }

    func refreshDocuments() {
        refreshTasks()
        documents = Self.loadDocuments(
            repository: repository,
            useStoredDocuments: useStoredDocuments
        )
    }

    private static func loadDocuments(
        repository: any DashboardRepository,
        useStoredDocuments: Bool
    ) -> [LifeDocument] {
        guard useStoredDocuments else {
            return repository.fetchDocuments()
        }

        let storedDocuments = PDFDocumentStore.load()
        guard !storedDocuments.isEmpty else {
            return repository.fetchDocuments()
        }

        return storedDocuments.map { document in
            let tint: Color

            switch document.category.lowercased() {
            case "finance":
                tint = .green
            case "study", "education":
                tint = .purple
            case "personal", "identity":
                tint = .blue
            default:
                tint = .orange
            }

            return LifeDocument(
                id: document.id,
                title: document.title,
                category: document.category,
                updatedLabel: document.importedAt.formatted(date: .abbreviated, time: .omitted),
                symbol: "doc.text",
                tint: tint
            )
        }
    }

    var filteredDocuments: [LifeDocument] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return documents
        }

        return documents.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.category.localizedCaseInsensitiveContains(query)
        }
    }

    func selectAction(_ action: String) {
        selectedActionMessage = "\(action) will be available in a future milestone."
    }
}
