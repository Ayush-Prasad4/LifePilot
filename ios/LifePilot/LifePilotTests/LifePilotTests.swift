import Foundation
import Testing
@testable import LifePilot

@MainActor
struct LifePilotTests {
    @Test func importingInvalidPDFThrowsWithoutImportingIt() throws {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")

        try Data("This is not a PDF".utf8).write(to: temporaryURL)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        var didThrow = false
        do {
            _ = try PDFDocumentStore.importPDFs(from: [temporaryURL], existing: [])
        } catch {
            didThrow = true
        }

        #expect(didThrow)
    }

    @Test func dashboardLoadsInitialData() {
        let viewModel = DashboardViewModel(useStoredDocuments: false)

        #expect(viewModel.tasks.count == 2)
        #expect(viewModel.documents.count == 3)
    }

    @Test func emptySearchShowsAllDocuments() {
        let viewModel = DashboardViewModel(useStoredDocuments: false)

        viewModel.searchText = ""

        #expect(viewModel.filteredDocuments.count == 3)
    }

    @Test func searchFindsDocumentByTitle() {
        let viewModel = DashboardViewModel(useStoredDocuments: false)

        viewModel.searchText = "Personal"

        #expect(viewModel.filteredDocuments.count == 1)
        #expect(viewModel.filteredDocuments.first?.title == "Personal documents")
    }

    @Test func searchFindsDocumentByCategory() {
        let viewModel = DashboardViewModel(useStoredDocuments: false)

        viewModel.searchText = "Finance"

        #expect(viewModel.filteredDocuments.count == 1)
        #expect(viewModel.filteredDocuments.first?.category == "Finance")
    }

    @Test func unmatchedSearchReturnsNoDocuments() {
        let viewModel = DashboardViewModel(useStoredDocuments: false)

        viewModel.searchText = "NoMatchingDocument"

        #expect(viewModel.filteredDocuments.isEmpty)
    }

    @Test func dashboardSupportsEmptyTasks() {
        let viewModel = DashboardViewModel(repository: EmptyTasksRepository(), useStoredDocuments: false)

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
