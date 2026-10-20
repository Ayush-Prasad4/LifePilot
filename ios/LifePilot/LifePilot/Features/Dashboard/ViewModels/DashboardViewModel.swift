import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var searchText = ""
    @Published private(set) var tasks: [LifeTask]
    @Published private(set) var documents: [LifeDocument]
    @Published var selectedActionMessage: String?

    private let repository: any DashboardRepository
    private let useStoredDocuments: Bool

    init(
        repository: any DashboardRepository = DashboardService(),
        useStoredDocuments: Bool = true
    ) {
        self.repository = repository
        self.tasks = repository.fetchTasks()
        self.documents = Self.loadDocuments(
            repository: repository,
            useStoredDocuments: useStoredDocuments
        )
        self.useStoredDocuments = useStoredDocuments
    }

    func refreshDocuments() {
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
                updatedLabel: document.updatedLabel,
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
