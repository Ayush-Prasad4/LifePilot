import SwiftUI
import PDFKit
import Vision

private struct PDFSearchResult: Identifiable {
    let documentID: UUID
    let documentTitle: String
    let pageNumber: Int
    let excerpt: String
    let score: Int

    var id: String { "\(documentID.uuidString)-\(pageNumber)" }
}

struct PDFDocumentAssistantView: View {
    @State private var documents = PDFDocumentStore.load()
    @State private var question = ""
    @State private var results: [PDFSearchResult] = []
    @State private var hasSearched = false
    @State private var statusMessage: String?
    @State private var aiAnswer: String?
    @State private var aiError: String?
    @State private var isAskingAI = false

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
                        Label("Search documents", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    private func extractText(from page: PDFPage) -> String? {
        if let text = page.string,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }

        // OCR fallback for scanned or image-only PDF pages.
        let image = page.thumbnail(
            of: CGSize(width: 1800, height: 2400),
            for: .mediaBox
        )

        guard let cgImage = image.cgImage else { return nil }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US", "it-IT"]

        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:])
                .perform([request])

            let recognizedLines = request.results?.compactMap {
                $0.topCandidates(1).first?.string
            } ?? []

            let text = recognizedLines.joined(separator: " ")
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }

    private func searchDocuments() {
        documents = PDFDocumentStore.load()
        results = []
        hasSearched = true
        statusMessage = nil

        let terms = Set(
            question.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 2 }
        )

        guard !terms.isEmpty else {
            statusMessage = "Enter a question with searchable keywords."
            return
        }

        guard !documents.isEmpty else {
            statusMessage = "Import a PDF first from the Documents tab."
            return
        }

        var matches: [PDFSearchResult] = []
        var readablePDFCount = 0

        for storedDocument in documents {
            let url = PDFDocumentStore.fileURL(for: storedDocument)
            guard let pdf = PDFDocument(url: url) else { continue }

            var foundText = false

            for pageIndex in 0..<pdf.pageCount {
                guard let page = pdf.page(at: pageIndex),
                      let pageText = extractText(from: page) else { continue }
                let normalizedText = pageText.lowercased()
                guard !normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continue
                }
                foundText = true

                let score = terms.reduce(into: 0) { total, term in
                    if normalizedText.contains(term) {
                        total += 1
                    }
                }

                guard score > 0 else { continue }

                let excerpt = pageText
                    .replacingOccurrences(of: "\n", with: " ")
                    .split(whereSeparator: { $0.isWhitespace })
                    .joined(separator: " ")

                matches.append(
                    PDFSearchResult(
                        documentID: storedDocument.id,
                        documentTitle: storedDocument.title,
                        pageNumber: pageIndex + 1,
                        excerpt: String(excerpt.prefix(700)),
                        score: score
                    )
                )
            }

            if foundText { readablePDFCount += 1 }
        }

        results = Array(
            matches.sorted { $0.score > $1.score }.prefix(10)
        )

        if readablePDFCount == 0 {
            statusMessage = "No selectable text found. This may be a scanned PDF that needs OCR."
        } else if results.isEmpty {
            statusMessage = "Searched \(readablePDFCount) PDF(s). No pages matched those keywords."
        } else {
            statusMessage = "Found \(results.count) relevant page(s) across your PDFs. These are matching passages, not AI-generated answers."
        }
    }
}
