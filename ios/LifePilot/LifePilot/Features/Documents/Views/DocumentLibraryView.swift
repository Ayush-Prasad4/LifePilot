import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct StoredPDFDocument: Identifiable, Codable, Sendable {
    let id: UUID
    var title: String
    var category: String
    let filename: String
    let importedAt: Date

    init(title: String, category: String, filename: String) {
        self.id = UUID()
        self.title = title
        self.category = category
        self.filename = filename
        self.importedAt = Date()
    }

    var updatedLabel: String {
        importedAt.formatted(date: .abbreviated, time: .omitted)
    }
}

enum PDFDocumentStoreError: Error {
    case invalidPDF
    case documentNotFound
}

enum PDFDocumentStore {
    private static let metadataFilename = "lifepilot-documents.json"

    private static var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static var metadataURL: URL {
        directory.appendingPathComponent(metadataFilename)
    }

    // Injectable directory keeps tests isolated from the user's real library.
    static func load(from directory: URL? = nil) -> [StoredPDFDocument] {
        let root = directory ?? self.directory
        let metadataURL = root.appendingPathComponent(metadataFilename)

        guard
            let data = try? Data(contentsOf: metadataURL),
            let documents = try? JSONDecoder().decode([StoredPDFDocument].self, from: data)
        else {
            return []
        }

        return documents.filter {
            FileManager.default.fileExists(
                atPath: root.appendingPathComponent($0.filename).path
            )
        }.sorted { $0.importedAt > $1.importedAt }
    }

    static func fileURL(for document: StoredPDFDocument, in directory: URL? = nil) -> URL {
        (directory ?? self.directory).appendingPathComponent(document.filename)
    }

    static func importPDFs(
        from urls: [URL],
        existing: [StoredPDFDocument],
        in directory: URL? = nil
    ) throws -> [StoredPDFDocument] {
        let root = directory ?? self.directory
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        let metadataURL = root.appendingPathComponent(metadataFilename)
        var documents = existing
        var copiedFiles: [URL] = []

        do {
            for sourceURL in urls {
                let hasAccess = sourceURL.startAccessingSecurityScopedResource()
                defer {
                    if hasAccess {
                        sourceURL.stopAccessingSecurityScopedResource()
                    }
                }

                guard sourceURL.pathExtension.lowercased() == "pdf" else {
                    continue
                }

                guard let pdf = PDFDocument(url: sourceURL), pdf.pageCount > 0 else {
                    throw PDFDocumentStoreError.invalidPDF
                }

                let filename = "\(UUID().uuidString).pdf"
                let destination = root.appendingPathComponent(filename)
                try FileManager.default.copyItem(at: sourceURL, to: destination)
                copiedFiles.append(destination)

                let title = sourceURL.deletingPathExtension().lastPathComponent
                documents.append(
                    StoredPDFDocument(
                        title: title.isEmpty ? "Untitled PDF" : title,
                        category: category(for: title),
                        filename: filename
                    )
                )
            }

            try save(documents, to: metadataURL)
            return documents.sorted { $0.importedAt > $1.importedAt }
        } catch {
            for url in copiedFiles {
                try? FileManager.default.removeItem(at: url)
            }
            throw error
        }
    }

    static func update(
        documentID: UUID,
        title: String? = nil,
        category: String? = nil,
        existing: [StoredPDFDocument],
        in directory: URL? = nil
    ) throws -> [StoredPDFDocument] {
        let root = directory ?? self.directory
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        var updated = existing
        guard let index = updated.firstIndex(where: { $0.id == documentID }) else {
            throw PDFDocumentStoreError.documentNotFound
        }

        if let title { updated[index].title = title }
        if let category { updated[index].category = category }

        try save(updated, to: root.appendingPathComponent(metadataFilename))
        return updated.sorted { $0.importedAt > $1.importedAt }
    }

    static func delete(
        _ document: StoredPDFDocument,
        existing: [StoredPDFDocument],
        in directory: URL? = nil
    ) throws -> [StoredPDFDocument] {
        let root = directory ?? self.directory
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        let updated = existing.filter { $0.id != document.id }
        let originalURL = root.appendingPathComponent(document.filename)
        let stagedURL = root.appendingPathComponent(
            ".lifepilot-delete-\(UUID().uuidString)-\(document.filename)"
        )
        let fileExists = FileManager.default.fileExists(atPath: originalURL.path)

        if fileExists {
            try FileManager.default.moveItem(at: originalURL, to: stagedURL)
        }

        do {
            try save(updated, to: root.appendingPathComponent(metadataFilename))
        } catch {
            if fileExists {
                try? FileManager.default.moveItem(at: stagedURL, to: originalURL)
            }
            throw error
        }

        if fileExists {
            try? FileManager.default.removeItem(at: stagedURL)
        }

        return updated.sorted { $0.importedAt > $1.importedAt }
    }

    private static func category(for title: String) -> String {
        let value = title.lowercased()

        if ["invoice", "bank", "finance", "receipt", "tax"].contains(where: value.contains) {
            return "Finance"
        }
        if ["study", "lecture", "exam", "course", "notes", "university"].contains(where: value.contains) {
            return "Study"
        }
        if ["passport", "identity", "personal", "document"].contains(where: value.contains) {
            return "Personal"
        }
        return "Other"
    }

    private static func save(_ documents: [StoredPDFDocument], to metadataURL: URL) throws {
        let data = try JSONEncoder().encode(documents)
        try data.write(to: metadataURL, options: .atomic)
    }
}

struct DocumentLibraryView: View {
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var documents: [StoredPDFDocument] = PDFDocumentStore.load()
    @State private var showingImporter = false
    @State private var errorMessage: String?
    @State private var documentToRename: StoredPDFDocument?
    @State private var renameTitle = ""
    @State private var showingRenameSheet = false
    @State private var documentToDelete: StoredPDFDocument?

    private var categories: [String] {
        ["All"] + Array(Set(documents.map(\.category))).sorted()
    }

    private var filteredDocuments: [StoredPDFDocument] {
        documents.filter { document in
            let matchesCategory = selectedCategory == "All"
                || document.category == selectedCategory
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty
                || document.title.localizedCaseInsensitiveContains(query)
                || document.category.localizedCaseInsensitiveContains(query)
            return matchesCategory && matchesSearch
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your documents")
                        .font(.largeTitle.bold())

                    Text("Keep your important files organised in one place.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    showingImporter = true
                } label: {
                    Label("Import PDF files", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Search documents", text: $searchText)
                        .autocorrectionDisabled()
                }
                .padding(14)
                .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                Text(category)
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 9)
                                    .background(
                                        selectedCategory == category
                                            ? Color.accentColor
                                            : Color.secondary.opacity(0.10),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(
                                        selectedCategory == category ? Color.white : Color.primary
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack {
                    Text("All files")
                        .font(.title3.bold())

                    Spacer()

                    Text("\(filteredDocuments.count) items")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if filteredDocuments.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No documents yet" : "No matching documents",
                        systemImage: searchText.isEmpty ? "doc.badge.plus" : "magnifyingglass",
                        description: Text(
                            searchText.isEmpty
                                ? "Import a PDF from the Files app to get started."
                                : "Try another search or category."
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredDocuments) { document in
                            HStack(spacing: 8) {
                                NavigationLink {
                                    PDFDocumentDetailView(document: document)
                                } label: {
                                    DocumentRowView(document: document)
                                }
                                .buttonStyle(.plain)

                                Menu {
                                    Button {
                                        documentToRename = document
                                        renameTitle = document.title
                                        showingRenameSheet = true
                                    } label: {
                                        Label("Rename", systemImage: "pencil")
                                    }

                                    Menu {
                                        ForEach(["Finance", "Study", "Personal", "Other"], id: \.self) { category in
                                            Button {
                                                updateCategory(document, to: category)
                                            } label: {
                                                if document.category == category {
                                                    Label(category, systemImage: "checkmark")
                                                } else {
                                                    Text(category)
                                                }
                                            }
                                        }
                                    } label: {
                                        Label("Change Category", systemImage: "tag")
                                    }

                                    Button(role: .destructive) {
                                        documentToDelete = document
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 40, height: 52)
                                        .contentShape(Rectangle())
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Documents")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingRenameSheet) {
            NavigationStack {
                Form {
                    TextField("Document name", text: $renameTitle)
                        .textInputAutocapitalization(.words)
                }
                .navigationTitle("Rename PDF")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingRenameSheet = false
                            documentToRename = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveRename() }
                            .disabled(renameTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog(
            "Delete this PDF?",
            isPresented: Binding(
                get: { documentToDelete != nil },
                set: { if !$0 { documentToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deleteSelectedDocument() }
            Button("Cancel", role: .cancel) { documentToDelete = nil }
        } message: {
            Text("This removes the PDF from LifePilot.")
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                do {
                    documents = try PDFDocumentStore.importPDFs(
                        from: urls,
                        existing: documents
                    )
                    selectedCategory = "All"
                } catch {
                    errorMessage = "Could not import the PDF. Please check the file and try again. \(error.localizedDescription)"
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .alert("Document import", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func saveRename() {
        guard let document = documentToRename else { return }
        let title = renameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            documents = try PDFDocumentStore.update(
                documentID: document.id,
                title: title,
                existing: documents
            )
            showingRenameSheet = false
            documentToRename = nil
        } catch {
            errorMessage = "Could not rename this PDF. \\(error.localizedDescription)"
        }
    }

    private func updateCategory(_ document: StoredPDFDocument, to category: String) {
        do {
            documents = try PDFDocumentStore.update(
                documentID: document.id,
                category: category,
                existing: documents
            )
        } catch {
            errorMessage = "Could not update the category. \\(error.localizedDescription)"
        }
    }

    private func deleteSelectedDocument() {
        guard let document = documentToDelete else { return }
        do {
            documents = try PDFDocumentStore.delete(document, existing: documents)
            documentToDelete = nil
        } catch {
            errorMessage = "Could not delete this PDF. \\(error.localizedDescription)"
            documentToDelete = nil
        }
    }
}

private struct DocumentRowView: View {
    let document: StoredPDFDocument

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.richtext")
                .font(.title2)
                .foregroundStyle(.red)
                .frame(width: 52, height: 52)
                .background(.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 15))

            VStack(alignment: .leading, spacing: 5) {
                Text(document.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(document.category)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Imported \(document.updatedLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(15)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.secondary.opacity(0.15), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct PDFDocumentDetailView: View {
    let document: StoredPDFDocument

    var body: some View {
        Group {
            if let pdf = PDFDocument(url: PDFDocumentStore.fileURL(for: document)) {
                PDFKitPreview(document: pdf)
                    .background(.secondary.opacity(0.06))
            } else {
                ContentUnavailableView(
                    "Unable to open PDF",
                    systemImage: "doc.questionmark",
                    description: Text("The local PDF file may be missing or damaged.")
                )
            }
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PDFKitPreview: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = document
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .secondarySystemBackground
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document !== document {
            view.document = document
        }
        view.autoScales = true
    }
}

#Preview {
    NavigationStack {
        DocumentLibraryView()
    }
}
