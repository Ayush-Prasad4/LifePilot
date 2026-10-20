import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var searchText = ""
    @Published private(set) var tasks: [LifeTask]
    @Published private(set) var documents: [LifeDocument]
    @Published var selectedActionMessage: String?

    private let repository: any DashboardRepository

    init(repository: any DashboardRepository = DashboardService()) {
        self.repository = repository
        self.tasks = repository.fetchTasks()
        self.documents = Self.loadStoredDocuments()
    }

    func refreshDocuments() {
        documents = Self.loadStoredDocuments()
    }

    private static func loadStoredDocuments() -> [LifeDocument] {
        PDFDocumentStore.load().map { document in
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
