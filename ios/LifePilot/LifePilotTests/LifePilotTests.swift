import Testing
@testable import LifePilot

@MainActor
struct LifePilotTests {
    @Test func dashboardLoadsInitialData() {
        let viewModel = DashboardViewModel()

        #expect(viewModel.tasks.count == 2)
        #expect(viewModel.documents.count == 3)
    }

    @Test func emptySearchShowsAllDocuments() {
        let viewModel = DashboardViewModel()

        viewModel.searchText = ""

        #expect(viewModel.filteredDocuments.count == 3)
    }

    @Test func searchFindsDocumentByTitle() {
        let viewModel = DashboardViewModel()

        viewModel.searchText = "Personal"

        #expect(viewModel.filteredDocuments.count == 1)
        #expect(viewModel.filteredDocuments.first?.title == "Personal documents")
    }

    @Test func searchFindsDocumentByCategory() {
        let viewModel = DashboardViewModel()

        viewModel.searchText = "Finance"

        #expect(viewModel.filteredDocuments.count == 1)
        #expect(viewModel.filteredDocuments.first?.category == "Finance")
    }

    @Test func unmatchedSearchReturnsNoDocuments() {
        let viewModel = DashboardViewModel()

        viewModel.searchText = "NoMatchingDocument"

        #expect(viewModel.filteredDocuments.isEmpty)
    }

    @Test func dashboardSupportsEmptyTasks() {
        let viewModel = DashboardViewModel(repository: EmptyTasksRepository())

        #expect(viewModel.tasks.isEmpty)
        #expect(viewModel.documents.count == 3)
    }

}


private struct EmptyTasksRepository: DashboardRepository {
    func fetchTasks() -> [LifeTask] {
        []
    }

    func fetchDocuments() -> [LifeDocument] {
        DashboardService().fetchDocuments()
    }
}
