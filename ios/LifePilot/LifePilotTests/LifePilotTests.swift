import Foundation
import Testing
import UIKit
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
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let document = StoredPDFDocument(
            title: "Original title",
            category: "Other",
            filename: "test-document.pdf"
        )

        try Data().write(
            to: directory.appendingPathComponent(document.filename)
        )

        let updated = try PDFDocumentStore.update(
            documentID: document.id,
            title: "Renamed study notes",
            category: "Study",
            existing: [document],
            in: directory
        )

        #expect(updated.first?.title == "Renamed study notes")
        #expect(updated.first?.category == "Study")

        let reloaded = PDFDocumentStore.load(from: directory)
        #expect(reloaded.count == 1)
        #expect(reloaded.first?.id == document.id)
        #expect(reloaded.first?.title == "Renamed study notes")
        #expect(reloaded.first?.category == "Study")
    }

    @Test func updatingUnknownDocumentIDDoesNotChangeExistingDocument() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let document = StoredPDFDocument(
            title: "Original title",
            category: "Other",
            filename: "existing-document.pdf"
        )
        let pdfURL = directory.appendingPathComponent(document.filename)
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: 200, height: 200)
        )
        try renderer.pdfData { context in
            context.beginPage()
        }.write(to: pdfURL)

        _ = try PDFDocumentStore.importPDFs(
            from: [pdfURL],
            existing: [],
            in: directory
        )
        let savedDocument = try #require(
            PDFDocumentStore.load(from: directory).first
        )

        var didThrow = false
        do {
            _ = try PDFDocumentStore.update(
                documentID: UUID(),
                title: "Unexpected rename",
                category: "Finance",
                existing: [savedDocument],
                in: directory
            )
        } catch {
            didThrow = true
        }

        #expect(didThrow)

        let reloaded = PDFDocumentStore.load(from: directory)
        #expect(reloaded.count == 1)
        #expect(reloaded.first?.id == savedDocument.id)
        #expect(reloaded.first?.title == "existing-document")
        #expect(reloaded.first?.category == "Personal")
    }

    @Test func deletingMissingFileRemovesDocumentFromMetadata() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let document = StoredPDFDocument(
            title: "Temporary regression test",
            category: "Other",
            filename: "missing-regression-test-file.pdf"
        )

        let remaining = try PDFDocumentStore.delete(
            document,
            existing: [document],
            in: directory
        )

        #expect(remaining.isEmpty)
        #expect(PDFDocumentStore.load(from: directory).isEmpty)
    }

    @Test func deletingOneDocumentPreservesOtherDocumentsInResult() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

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

        try Data().write(
            to: directory.appendingPathComponent(second.filename)
        )

        let remaining = try PDFDocumentStore.delete(
            first,
            existing: [first, second],
            in: directory
        )

        #expect(remaining.count == 1)
        #expect(remaining.first?.id == second.id)

        let reloaded = PDFDocumentStore.load(from: directory)
        #expect(reloaded.count == 1)
        #expect(reloaded.first?.id == second.id)
        #expect(reloaded.first?.title == second.title)
    }


    @Test func importingValidPDFPersistsFileAndMetadata() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sourceDirectory = root.appendingPathComponent("source", isDirectory: true)
        let destinationDirectory = root.appendingPathComponent("store", isDirectory: true)

        try FileManager.default.createDirectory(
            at: sourceDirectory, withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: destinationDirectory, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let source = sourceDirectory.appendingPathComponent("Study Notes.pdf")
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: 200, height: 200)
        )
        try renderer.pdfData { context in
            context.beginPage()
        }.write(to: source)

        let imported = try PDFDocumentStore.importPDFs(
            from: [source], existing: [], in: destinationDirectory
        )

        #expect(imported.count == 1)
        #expect(imported.first?.title == "Study Notes")

        let stored = try #require(imported.first)
        let storedURL = destinationDirectory.appendingPathComponent(stored.filename)
        #expect(FileManager.default.fileExists(atPath: storedURL.path))

        let reloaded = PDFDocumentStore.load(from: destinationDirectory)
        #expect(reloaded.count == 1)
        #expect(reloaded.first?.id == stored.id)
        #expect(reloaded.first?.title == "Study Notes")
    }

    @Test func failedMultiPDFImportCleansUpPreviouslyCopiedFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sourceDirectory = root.appendingPathComponent("source", isDirectory: true)
        let destinationDirectory = root.appendingPathComponent("store", isDirectory: true)

        try FileManager.default.createDirectory(
            at: sourceDirectory, withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: destinationDirectory, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let validPDF = sourceDirectory.appendingPathComponent("Valid.pdf")
        let invalidPDF = sourceDirectory.appendingPathComponent("Invalid.pdf")
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: 200, height: 200)
        )
        try renderer.pdfData { context in
            context.beginPage()
        }.write(to: validPDF)
        try Data("not a PDF".utf8).write(to: invalidPDF)

        var didThrow = false
        do {
            _ = try PDFDocumentStore.importPDFs(
                from: [validPDF, invalidPDF],
                existing: [],
                in: destinationDirectory
            )
        } catch {
            didThrow = true
        }

        #expect(didThrow)
        #expect(try FileManager.default.contentsOfDirectory(
            atPath: destinationDirectory.path
        ).isEmpty)
        #expect(PDFDocumentStore.load(from: destinationDirectory).isEmpty)
    }


    @Test func importRollsBackCopiedFilesWhenMetadataSaveFails() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sourceDirectory = root.appendingPathComponent("source", isDirectory: true)
        let storeDirectory = root.appendingPathComponent("store", isDirectory: true)

        try FileManager.default.createDirectory(
            at: sourceDirectory, withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: storeDirectory, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let source = sourceDirectory.appendingPathComponent("Rollback Test.pdf")
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: 200, height: 200)
        )
        try renderer.pdfData { context in
            context.beginPage()
        }.write(to: source)

        // Force metadata persistence to fail: the metadata path is a directory.
        let metadataBlocker = storeDirectory
            .appendingPathComponent("lifepilot-documents.json")
        try FileManager.default.createDirectory(
            at: metadataBlocker, withIntermediateDirectories: false
        )

        var didThrow = false
        do {
            _ = try PDFDocumentStore.importPDFs(
                from: [source], existing: [], in: storeDirectory
            )
        } catch {
            didThrow = true
        }

        #expect(didThrow)

        let remainingFiles = try FileManager.default.contentsOfDirectory(
            atPath: storeDirectory.path
        )
        #expect(!remainingFiles.contains(where: { $0.hasSuffix(".pdf") }))
        #expect(FileManager.default.fileExists(atPath: metadataBlocker.path))
    }

    @Test func deleteRestoresOriginalPDFWhenMetadataSaveFails() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let document = StoredPDFDocument(
            title: "Rollback Test",
            category: "Other",
            filename: "rollback-test.pdf"
        )
        let originalURL = directory.appendingPathComponent(document.filename)
        try Data("temporary test fixture".utf8).write(to: originalURL)

        // Force metadata persistence to fail after deletion stages the file.
        let metadataBlocker = directory.appendingPathComponent(
            "lifepilot-documents.json"
        )
        try FileManager.default.createDirectory(
            at: metadataBlocker, withIntermediateDirectories: false
        )

        var didThrow = false
        do {
            _ = try PDFDocumentStore.delete(
                document, existing: [document], in: directory
            )
        } catch {
            didThrow = true
        }

        #expect(didThrow)
        #expect(FileManager.default.fileExists(atPath: originalURL.path))

        let filenames = try FileManager.default.contentsOfDirectory(
            atPath: directory.path
        )
        #expect(!filenames.contains(where: { $0.hasPrefix(".lifepilot-delete-") }))
    }


    @Test func sameNamedPDFsImportAsSeparateDocuments() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sourceA = root.appendingPathComponent("source-a", isDirectory: true)
        let sourceB = root.appendingPathComponent("source-b", isDirectory: true)
        let store = root.appendingPathComponent("store", isDirectory: true)

        for directory in [sourceA, sourceB, store] {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true
            )
        }
        defer { try? FileManager.default.removeItem(at: root) }

        let firstSource = sourceA.appendingPathComponent("Lecture Notes.pdf")
        let secondSource = sourceB.appendingPathComponent("Lecture Notes.pdf")
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: 200, height: 200)
        )
        try renderer.pdfData { context in
            context.beginPage()
            "LifePilot PDF fixture".draw(
                at: CGPoint(x: 20, y: 20),
                withAttributes: [.font: UIFont.systemFont(ofSize: 12)]
            )
        }.write(to: firstSource)
        let secondRenderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: 200, height: 200)
        )
        try secondRenderer.pdfData { context in
            context.beginPage()
            "LifePilot PDF fixture".draw(
                at: CGPoint(x: 20, y: 20),
                withAttributes: [.font: UIFont.systemFont(ofSize: 12)]
            )
            "Second source".draw(
                at: CGPoint(x: 20, y: 20),
                withAttributes: [.font: UIFont.systemFont(ofSize: 12)]
            )
        }.write(to: secondSource)

        let imported = try PDFDocumentStore.importPDFs(
            from: [firstSource, secondSource], existing: [], in: store
        )

        #expect(imported.count == 2)
        #expect(imported.allSatisfy { $0.title == "Lecture Notes" })
        #expect(Set(imported.map(\.filename)).count == 2)
        #expect(imported.allSatisfy {
            FileManager.default.fileExists(
                atPath: store.appendingPathComponent($0.filename).path
            )
        })
    }

    @Test func reloadingStorePreservesMultipleImportedDocuments() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = root.appendingPathComponent("source", isDirectory: true)
        let store = root.appendingPathComponent("store", isDirectory: true)

        for directory in [source, store] {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true
            )
        }
        defer { try? FileManager.default.removeItem(at: root) }

        let firstPDF = source.appendingPathComponent("Exam Notes.pdf")
        let secondPDF = source.appendingPathComponent("Invoice 2026.pdf")
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: 200, height: 200)
        )
        try renderer.pdfData { context in
            context.beginPage()
            "LifePilot PDF fixture".draw(
                at: CGPoint(x: 20, y: 20),
                withAttributes: [.font: UIFont.systemFont(ofSize: 12)]
            )
        }.write(to: firstPDF)
        let secondRenderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: 200, height: 200)
        )
        try secondRenderer.pdfData { context in
            context.beginPage()
            "LifePilot PDF fixture".draw(
                at: CGPoint(x: 20, y: 20),
                withAttributes: [.font: UIFont.systemFont(ofSize: 12)]
            )
        }.write(to: secondPDF)

        let imported = try PDFDocumentStore.importPDFs(
            from: [firstPDF, secondPDF], existing: [], in: store
        )
        let reloaded = PDFDocumentStore.load(from: store)

        #expect(reloaded.count == 2)
        #expect(Set(reloaded.map(\.id)) == Set(imported.map(\.id)))
        #expect(Set(reloaded.map(\.title)) == Set(["Exam Notes", "Invoice 2026"]))
        #expect(reloaded.first(where: { $0.title == "Exam Notes" })?.category == "Study")
        #expect(reloaded.first(where: { $0.title == "Invoice 2026" })?.category == "Finance")
    }


    @Test func corruptedMetadataLoadsAsEmptyWithoutChangingTheFile() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let metadataURL = root.appendingPathComponent("lifepilot-documents.json")
        let corruptData = Data("{ invalid json".utf8)
        try corruptData.write(to: metadataURL)

        let loaded = PDFDocumentStore.load(from: root)

        #expect(loaded.isEmpty)
        #expect((try? Data(contentsOf: metadataURL)) == corruptData)
    }

    @Test func loadingStoreIgnoresDocumentsWhosePDFFileIsMissing() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = root.appendingPathComponent("source", isDirectory: true)
        let store = root.appendingPathComponent("store", isDirectory: true)

        for directory in [source, store] {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true
            )
        }
        defer { try? FileManager.default.removeItem(at: root) }

        let sourcePDF = source.appendingPathComponent("Lecture Notes.pdf")
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: 200, height: 200)
        )
        try renderer.pdfData { context in
            context.beginPage()
        }.write(to: sourcePDF)

        let imported = try PDFDocumentStore.importPDFs(
            from: [sourcePDF], existing: [], in: store
        )
        let document = try #require(imported.first)
        let storedPDF = store.appendingPathComponent(document.filename)
        try FileManager.default.removeItem(at: storedPDF)

        let loaded = PDFDocumentStore.load(from: store)

        #expect(loaded.isEmpty)
        #expect(FileManager.default.fileExists(
            atPath: store.appendingPathComponent("lifepilot-documents.json").path
        ))
    }


    @Test func importingOnlyUnsupportedFilesPreservesExistingLibrary() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = root.appendingPathComponent("source", isDirectory: true)
        let store = root.appendingPathComponent("store", isDirectory: true)

        for directory in [source, store] {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true
            )
        }
        defer { try? FileManager.default.removeItem(at: root) }

        let existingPDF = store.appendingPathComponent("existing.pdf")
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: 200, height: 200)
        )
        try renderer.pdfData { context in
            context.beginPage()
        }.write(to: existingPDF)

        let existing = StoredPDFDocument(
            title: "Existing Study Notes",
            category: "Study",
            filename: "existing.pdf"
        )
        let unsupportedFile = source.appendingPathComponent("notes.txt")
        try Data("not a PDF".utf8).write(to: unsupportedFile)

        let result = try PDFDocumentStore.importPDFs(
            from: [unsupportedFile], existing: [existing], in: store
        )
        let reloaded = PDFDocumentStore.load(from: store)

        #expect(result.count == 1)
        #expect(result.first?.id == existing.id)
        #expect(reloaded.count == 1)
        #expect(reloaded.first?.title == "Existing Study Notes")
        #expect(FileManager.default.fileExists(atPath: existingPDF.path))
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
