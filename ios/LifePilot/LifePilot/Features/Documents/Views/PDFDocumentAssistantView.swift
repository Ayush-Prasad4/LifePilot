import SwiftUI

struct PDFDocumentAssistantView: View {
    @State private var documents = PDFDocumentStore.load()
    @State private var question = ""
    @State private var results: [PDFSearchResult] = []
    @State private var hasSearched = false
    @State private var statusMessage: String?
    @State private var aiAnswer: String?
    @State private var aiError: String?
    @State private var isAskingAI = false
    @State private var isSearching = false
    @State private var searchTask: Task<PDFDocumentSearchOutcome?, Never>?
    @State private var activeSearchID: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.tint)

                    Text("Ask your documents")
                        .font(.largeTitle.bold())

                    Text("Search the content of your imported PDFs and find the pages relevant to your question.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    TextField("Ask about your PDFs…", text: $question, axis: .vertical)
                        .lineLimit(2...5)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("documentQuestionField")

                    Button(action: searchDocuments) {
                        if isSearching {
                            ProgressView("Searching PDFs…")
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Search documents", systemImage: "magnifyingglass")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        isSearching ||
                        question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                    .accessibilityIdentifier("searchDocumentsButton")
                }

                if documents.isEmpty {
                    ContentUnavailableView(
                        "No PDFs yet",
                        systemImage: "doc.text",
                        description: Text("Import a PDF in the Documents tab, then return here to search its content.")
                    )
                } else {
                    Label("\(documents.count) PDF\(documents.count == 1 ? "" : "s") available", systemImage: "doc.text")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if hasSearched && results.isEmpty {
                    ContentUnavailableView(
                        "No matching passages",
                        systemImage: "text.magnifyingglass",
                        description: Text("Try different keywords or check that your PDF contains selectable text.")
                    )
                }

                ForEach(results) { result in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(result.documentTitle)
                            .font(.headline)

                        Label("Page \(result.pageNumber)", systemImage: "doc.text")
                            .font(.caption)
                            .foregroundStyle(.tint)

                        Text(result.excerpt)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                }
                if !results.isEmpty {
                    Button(action: askAI) {
                        if isAskingAI {
                            ProgressView("Generating answer…")
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Ask AI about these passages", systemImage: "sparkles")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAskingAI)
                    .accessibilityIdentifier("askAIDocumentsButton")
                }

                if let aiError {
                    Text(aiError)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }

                if let aiAnswer {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("AI Answer", systemImage: "sparkles")
                            .font(.headline)

                        Text(aiAnswer)
                            .textSelection(.enabled)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(20)
        }
        .navigationTitle("AI Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            documents = PDFDocumentStore.load()
        }
        .onDisappear {
            activeSearchID = nil
            searchTask?.cancel()
            searchTask = nil
            isSearching = false
        }
    }

    private func askAI() {
        guard !results.isEmpty else { return }

        isAskingAI = true
        aiAnswer = nil
        aiError = nil

        let currentQuestion = question
        let evidence = results.map { result in
            AIAnswerRequest.Evidence(
                document_title: result.documentTitle,
                page: result.pageNumber,
                excerpt: result.excerpt
            )
        }

        Task { @MainActor in
            defer { isAskingAI = false }

            do {
                let response = try await LifePilotAIService().answer(
                    question: currentQuestion,
                    evidence: evidence
                )
                aiAnswer = response.answer
            } catch {
                aiError = error.localizedDescription
            }
        }
    }

    private func searchDocuments() {
        let currentQuestion = question
        let currentDocuments = PDFDocumentStore.load()

        documents = currentDocuments
        results = []
        hasSearched = true
        statusMessage = nil
        aiAnswer = nil
        aiError = nil

        let searchID = UUID()
        activeSearchID = searchID
        isSearching = true

        searchTask?.cancel()

        let task = Task.detached(priority: .userInitiated) {
            PDFDocumentSearchService.search(
                documents: currentDocuments,
                question: currentQuestion
            )
        }
        searchTask = task

        Task { @MainActor in
            let outcome = await task.value

            // A previous or cancelled search must not overwrite newer state.
            guard activeSearchID == searchID else { return }

            searchTask = nil
            activeSearchID = nil
            isSearching = false

            guard let outcome else { return }
            results = outcome.results
            statusMessage = outcome.statusMessage
        }
    }
}
