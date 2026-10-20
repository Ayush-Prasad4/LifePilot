import SwiftUI

struct DocumentLibraryView: View {
    @State private var searchText = ""
    @State private var selectedCategory = "All"

    private let documents = DashboardService().fetchDocuments()

    private var categories: [String] {
        ["All"] + Array(Set(documents.map(\.category))).sorted()
    }

    private var filteredDocuments: [LifeDocument] {
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
                                        selectedCategory == category
                                            ? Color.white
                                            : Color.primary
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
                    ContentUnavailableView.search(text: searchText)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredDocuments) { document in
                            NavigationLink {
                                DocumentDetailView(document: document)
                            } label: {
                                DocumentRowView(document: document)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Documents")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DocumentRowView: View {
    let document: LifeDocument

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: document.symbol)
                .font(.title2)
                .foregroundStyle(document.tint)
                .frame(width: 52, height: 52)
                .background(document.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))

            VStack(alignment: .leading, spacing: 5) {
                Text(document.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(document.category)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(document.updatedLabel)
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

private struct DocumentDetailView: View {
    let document: LifeDocument

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: document.symbol)
                    .font(.system(size: 46))
                    .foregroundStyle(document.tint)
                    .frame(width: 104, height: 104)
                    .background(document.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 28))

                VStack(spacing: 8) {
                    Text(document.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text(document.category)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Label(document.updatedLabel, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ContentUnavailableView(
                    "No file attached",
                    systemImage: "doc",
                    description: Text("This is a sample document entry. Import a real file in a future milestone.")
                )
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
        .navigationTitle("Document details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DocumentLibraryView()
    }
}
