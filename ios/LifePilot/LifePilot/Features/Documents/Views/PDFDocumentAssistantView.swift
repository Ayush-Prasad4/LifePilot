import SwiftUI
import PDFKit

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
    @State private var selectedPDFResult: PDFSearchResult?

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
                    Button {
                        selectedPDFResult = result
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(result.documentTitle)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Label("Page \(result.pageNumber) · Tap to open", systemImage: "doc.text")
                                .font(.caption)
                                .foregroundStyle(.tint)

                            Text(result.excerpt)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .textSelection(.enabled)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        .contentShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens this PDF at page \(result.pageNumber)")
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

                        Text(linkedAIAnswer(aiAnswer))
                            .textSelection(.enabled)
                            .environment(\.openURL, OpenURLAction { url in
                                guard url.scheme == "lifepilot",
                                      url.host == "pdf" else {
                                    return .systemAction
                                }

                                let parts = url.pathComponents.filter { $0 != "/" }
                                guard parts.count == 2,
                                      let documentID = UUID(uuidString: parts[0]),
                                      let pageNumber = Int(parts[1]),
                                      let result = results.first(where: {
                                          $0.documentID == documentID &&
                                          $0.pageNumber == pageNumber
                                      }) else {
                                    return .discarded
                                }

                                selectedPDFResult = result
                                return .handled
                            })
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
        .sheet(item: $selectedPDFResult) { result in
            NavigationStack {
                PDFSearchResultDetailView(result: result)
            }
        }
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

    private func linkedAIAnswer(_ answer: String) -> AttributedString {
        var attributed = AttributedString(answer)

        for result in results {
            let title = NSRegularExpression.escapedPattern(for: result.documentTitle)
            let pattern = "\(title)\\s*,\\s*p\\.?\\s*\(result.pageNumber)\\b"

            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            ) else {
                continue
            }

            let matches = regex.matches(
                in: answer,
                range: NSRange(answer.startIndex..., in: answer)
            )

            for match in matches.reversed() {
                guard let range = Range(match.range, in: attributed),
                      let url = URL(
                          string: "lifepilot://pdf/\(result.documentID.uuidString)/\(result.pageNumber)"
                      ) else {
                    continue
                }

                attributed[range].link = url
            }
        }

        return attributed
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


private struct PDFSearchResultDetailView: View {
    let result: PDFSearchResult

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            let document = PDFDocumentStore.load().first {
                $0.id == result.documentID
            }

            if let document,
               let pdf = PDFDocument(url: PDFDocumentStore.fileURL(for: document)),
               result.pageNumber > 0,
               result.pageNumber <= pdf.pageCount {
                PDFSearchResultPDFPreview(
                    document: pdf,
                    pageNumber: result.pageNumber
                )
                .background(.secondary.opacity(0.06))
            } else {
                ContentUnavailableView(
                    "Unable to open this page",
                    systemImage: "doc.questionmark",
                    description: Text("The PDF may have been deleted, moved, or changed since the search.")
                )
            }
        }
        .navigationTitle(result.documentTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

private struct PDFSearchResultPDFPreview: UIViewRepresentable {
    let document: PDFDocument
    let pageNumber: Int

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .secondarySystemBackground
        view.document = document
        navigate(view)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document !== document {
            view.document = document
        }
        view.autoScales = true
        navigate(view)
    }

    private func navigate(_ view: PDFView) {
        guard let page = document.page(at: pageNumber - 1) else { return }
        view.go(to: page)
    }
}
