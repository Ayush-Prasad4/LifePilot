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

    @Test func updatingDocumentPersistsTitleAndCategory() throws {
        let document = StoredPDFDocument(
            title: "Original title",
            category: "Other",
            filename: "test-document-do-not-create.pdf"
        )

        let updated = try PDFDocumentStore.update(
            documentID: document.id,
            title: "Renamed study notes",
            category: "Study",
            existing: [document]
        )

        #expect(updated.count == 1)
        #expect(updated.first?.title == "Renamed study notes")
        #expect(updated.first?.category == "Study")

        // Restore metadata to its previous state; this test creates no PDF files.
        _ = try PDFDocumentStore.update(
            documentID: document.id,
            title: document.title,
            category: document.category,
            existing: updated
        )
    }

    @Test func deletingMissingFileRemovesDocumentFromMetadata() throws {
        let document = StoredPDFDocument(
            title: "Temporary regression test",
            category: "Other",
            filename: "missing-regression-test-file.pdf"
        )

        let remaining = try PDFDocumentStore.delete(document, existing: [document])

        #expect(remaining.isEmpty)
        #expect(!FileManager.default.fileExists(
            atPath: PDFDocumentStore.fileURL(for: document).path
        ))
    }

    @Test func deletingOneDocumentPreservesOtherDocumentsInResult() throws {
        let first = StoredPDFDocument(
            title: "First test document",
            category: "Other",
            filename: "missing-first-regression-test.pdf"
        )
        let second = StoredPDFDocument(
            title: "Second test document",
            category: "Study",
            filename: "missing-second-regression-test.pdf"
        )

        let remaining = try PDFDocumentStore.delete(first, existing: [first, second])

        #expect(remaining.count == 1)
        #expect(remaining.first?.id == second.id)
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
