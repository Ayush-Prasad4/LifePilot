import Foundation
import PDFKit
import Vision

struct PDFSearchResult: Identifiable, Sendable {
    let documentID: UUID
    let documentTitle: String
    let pageNumber: Int
    let excerpt: String
    let score: Int

    var id: String { "\(documentID.uuidString)-\(pageNumber)" }
}

struct PDFDocumentSearchOutcome: Sendable {
    let results: [PDFSearchResult]
    let statusMessage: String?
}

enum PDFDocumentSearchService {
    static func searchTerms(for question: String) -> Set<String> {
        Set(
            question.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 2 }
        )
    }

    // Run this synchronous PDFKit/Vision work on a background task.
    // PDFDocument and PDFPage instances stay within this operation.
    static func search(
        documents: [StoredPDFDocument],
        question: String
    ) -> PDFDocumentSearchOutcome? {
        let terms = searchTerms(for: question)

        guard !terms.isEmpty else {
            return PDFDocumentSearchOutcome(
                results: [],
                statusMessage: "Enter a question with searchable keywords."
            )
        }

        guard !documents.isEmpty else {
            return PDFDocumentSearchOutcome(
                results: [],
                statusMessage: "Import a PDF first from the Documents tab."
            )
        }

        var matches: [PDFSearchResult] = []
        var readablePDFCount = 0

        for storedDocument in documents {
            guard !Task.isCancelled else { return nil }

            let url = PDFDocumentStore.fileURL(for: storedDocument)
            guard let pdf = PDFDocument(url: url) else { continue }

            var foundText = false

            for pageIndex in 0..<pdf.pageCount {
                guard !Task.isCancelled else { return nil }
                guard let page = pdf.page(at: pageIndex),
                      let pageText = extractText(from: page) else {
                    continue
                }

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

            if foundText {
                readablePDFCount += 1
            }
        }

        guard !Task.isCancelled else { return nil }

        let results = Array(matches.sorted { $0.score > $1.score }.prefix(10))
        let message: String?

        if readablePDFCount == 0 {
            message = "No selectable text found. This may be a scanned PDF that needs OCR."
        } else if results.isEmpty {
            message = "Searched \(readablePDFCount) PDF(s). No pages matched those keywords."
        } else {
            message = "Found \(results.count) relevant page(s) across your PDFs. These are matching passages, not AI-generated answers."
        }

        return PDFDocumentSearchOutcome(
            results: results,
            statusMessage: message
        )
    }

    private static func extractText(from page: PDFPage) -> String? {
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
}
