import SwiftUI

// MARK: - Dashboard View

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    let onAddDocument: () -> Void
    let onAskAI: () -> Void

    init(
        onAddDocument: @escaping () -> Void = {},
        onAskAI: @escaping () -> Void = {}
    ) {
        self.onAddDocument = onAddDocument
        self.onAskAI = onAskAI
    }

    private let ink = Color(red: 0.12, green: 0.17, blue: 0.25)
    private let canvas = Color(red: 0.96, green: 0.97, blue: 0.98)

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    searchBar
                    overviewSection
                    progressSection
                    tasksSection
                    documentsSection
                    quickActionsSection
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
            .background(canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .automatic)
            .alert(
                "LifePilot",
                isPresented: Binding(
                    get: { viewModel.selectedActionMessage != nil },
                    set: { if !$0 { viewModel.selectedActionMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    viewModel.selectedActionMessage = nil
                }
            } message: {
                Text(viewModel.selectedActionMessage ?? "")
            }
        }
        .onAppear {
            viewModel.refreshDocuments()
        }
        .tint(ink)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("LIFEPILOT")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(2.5)
                    .foregroundStyle(.secondary)

                Text("Your life,")
                    .font(.system(size: 32, weight: .regular, design: .rounded))
                    .foregroundStyle(ink)

                Text("in better order.")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
            }

            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(ink, in: RoundedRectangle(cornerRadius: 18))
                .accessibilityLabel("LifePilot")
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search your documents", text: $viewModel.searchText)
                .font(.system(size: 15))
                .autocorrectionDisabled()
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.black.opacity(0.05), lineWidth: 1)
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionHeading("Your overview", subtitle: "A little more organised every day")

            HStack(spacing: 12) {
                overviewCard(
                    value: "\(viewModel.documents.count)",
                    label: "Documents",
                    symbol: "folder",
                    tint: .blue
                )

                overviewCard(
                    value: "\(max(0, viewModel.totalTaskCount - viewModel.completedTaskCount))",
                    label: "Tasks left",
                    symbol: "checklist",
                    tint: .orange
                )
            }
        }
    }

    private var progressSection: some View {
        let total = viewModel.totalTaskCount
        let completed = viewModel.completedTaskCount
        let fraction = total == 0 ? 0.0 : Double(completed) / Double(total)

        return VStack(alignment: .leading, spacing: 14) {
            sectionHeading("Daily progress", subtitle: "Small steps add up")

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(total == 0 ? "No tasks yet" : "\(completed) of \(total) completed")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ink)
                    Spacer()
                    if total > 0 {
                        Text("\(Int(fraction * 100))%")
                            .font(.system(size: 15, weight: .bold))
                    }
                }

                ProgressView(value: fraction)
                    .tint(.green)

                Text(total == 0
                     ? "Add a task in Calendar to track your progress."
                     : "Progress updates from your Calendar tasks.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func overviewCard(
        value: String,
        label: String,
        symbol: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)

                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: 22))
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionHeading("Coming up", subtitle: "Things worth keeping an eye on")

            if viewModel.tasks.isEmpty {
                ContentUnavailableView(
                    "All caught up",
                    systemImage: "checkmark.circle",
                    description: Text("Your upcoming tasks will appear here.")
                )
                .frame(maxWidth: .infinity)
                .frame(minHeight: 130)
                .background(.white, in: RoundedRectangle(cornerRadius: 20))
            } else {
                ForEach(viewModel.tasks) { task in
                    HStack(spacing: 14) {
                    Image(systemName: task.symbol)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(task.priority == .important ? .orange : .blue)
                        .frame(width: 46, height: 46)
                        .background(
                            (task.priority == .important ? Color.orange : Color.blue)
                                .opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 15)
                        )

                    VStack(alignment: .leading, spacing: 5) {
                        Text(task.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ink)

                        Text(task.subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 4)

                    Text(task.dueLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(task.priority == .important ? .orange : .secondary)
                }
                .padding(15)
                .background(.white, in: RoundedRectangle(cornerRadius: 19))
                }
            }
        }
    }

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionHeading("Your documents", subtitle: "Everything in one place")

            if viewModel.filteredDocuments.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
                    .frame(minHeight: 150)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20))
            } else {
                ForEach(viewModel.filteredDocuments) { document in
                    HStack(spacing: 14) {
                        Image(systemName: document.symbol)
                            .font(.system(size: 19, weight: .medium))
                            .foregroundStyle(document.tint)
                            .frame(width: 48, height: 52)
                            .background(
                                document.tint.opacity(0.11),
                                in: RoundedRectangle(cornerRadius: 14)
                            )

                        VStack(alignment: .leading, spacing: 5) {
                            Text(document.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(ink)

                            Text("\(document.category) · \(document.updatedLabel)")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18))
                }
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionHeading("Quick actions", subtitle: "Your next step, made simpler")

            HStack(spacing: 12) {
                actionButton(
                    title: "Add document",
                    symbol: "plus",
                    tint: .blue
                ) {
                    onAddDocument()
                }

                actionButton(
                    title: "Ask AI",
                    symbol: "sparkles",
                    tint: .purple
                ) {
                    onAskAI()
                }
            }
        }
    }

    private func actionButton(
        title: String,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(tint)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ink)
            }
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 19))
            .contentShape(RoundedRectangle(cornerRadius: 19))
        }
        .buttonStyle(.plain)
    }

    private func sectionHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(ink)

            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }
}


#Preview {
    DashboardView()
}
