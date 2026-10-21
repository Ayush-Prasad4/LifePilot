import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(
                onAddDocument: { selectedTab = 1 },
                onAskAI: { selectedTab = 2 }
            )
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)

            NavigationStack {
                DocumentLibraryView()
            }
            .tabItem {
                Label("Documents", systemImage: "doc.text")
            }
            .tag(1)

            NavigationStack {
                AssistantView()
            }
            .tabItem {
                Label("Assistant", systemImage: "sparkles")
            }
            .tag(2)

            NavigationStack {
                CalendarView()
            }
            .tabItem {
                Label("Calendar", systemImage: "calendar")
            }
            .tag(3)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(4)
        }
    }
}

private struct AssistantView: View {
    var body: some View {
        PDFDocumentAssistantView()
    }
}

struct PlannerTask: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var dueDate: Date
    var priority: PlannerPriority
    var isCompleted = false
}

enum PlannerPriority: String, Codable, CaseIterable {
    case normal = "Normal"
    case important = "Important"
    case urgent = "Urgent"
}

struct CalendarTaskStore {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "lifepilot.planner.tasks"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func load() -> [PlannerTask] {
        guard let data = defaults.data(forKey: key),
              let tasks = try? JSONDecoder().decode([PlannerTask].self, from: data)
        else { return [] }
        return tasks
    }

    func save(_ tasks: [PlannerTask]) {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        defaults.set(data, forKey: key)
    }
}

private struct CalendarView: View {
    @State private var tasks = CalendarTaskStore().load()
    @State private var showingAddTask = false

    private var sortedTasks: [PlannerTask] {
        tasks.sorted {
            if $0.isCompleted != $1.isCompleted {
                return !$0.isCompleted
            }
            return $0.dueDate < $1.dueDate
        }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    summary("Open", value: tasks.filter { !$0.isCompleted }.count)
                    Spacer()
                    summary("Completed", value: tasks.filter(\.isCompleted).count)
                }
                .padding(.vertical, 6)
            }

            Section("Your tasks") {
                if sortedTasks.isEmpty {
                    ContentUnavailableView(
                        "No tasks yet",
                        systemImage: "calendar.badge.plus",
                        description: Text("Tap + to plan your first task.")
                    )
                }

                ForEach(sortedTasks) { task in
                    HStack(spacing: 12) {
                        Button {
                            update(task) { $0.isCompleted.toggle() }
                        } label: {
                            Image(systemName: task.isCompleted
                                  ? "checkmark.circle.fill"
                                  : "circle")
                                .font(.title2)
                                .foregroundStyle(task.isCompleted ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            task.isCompleted ? "Mark incomplete" : "Complete task"
                        )

                        VStack(alignment: .leading, spacing: 5) {
                            Text(task.title)
                                .font(.body.weight(.medium))
                                .strikethrough(task.isCompleted)

                            Text(task.dueDate.formatted(
                                date: .abbreviated, time: .shortened
                            ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(task.priority.rawValue)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(priorityColor(task.priority).opacity(0.12))
                            .foregroundStyle(priorityColor(task.priority))
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 4)
                    .swipeActions {
                        Button(role: .destructive) {
                            tasks.removeAll { $0.id == task.id }
                            persist()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Calendar")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddTask = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add task")
            }
        }
        .sheet(isPresented: $showingAddTask) {
            NavigationStack {
                PlannerTaskEditor { title, date, priority in
                    tasks.append(
                        PlannerTask(title: title, dueDate: date, priority: priority)
                    )
                    persist()
                }
            }
        }
    }

    private func summary(_ title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func priorityColor(_ priority: PlannerPriority) -> Color {
        switch priority {
        case .normal: .blue
        case .important: .orange
        case .urgent: .red
        }
    }

    private func update(
        _ task: PlannerTask,
        change: (inout PlannerTask) -> Void
    ) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else {
            return
        }
        change(&tasks[index])
        persist()
    }

    private func persist() {
        CalendarTaskStore().save(tasks)
    }
}

private struct PlannerTaskEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var dueDate = Date()
    @State private var priority: PlannerPriority = .normal

    let onSave: (String, Date, PlannerPriority) -> Void

    var body: some View {
        Form {
            Section("Task details") {
                TextField("What do you need to do?", text: $title)

                DatePicker(
                    "Due date",
                    selection: $dueDate,
                    displayedComponents: [.date, .hourAndMinute]
                )

                Picker("Priority", selection: $priority) {
                    ForEach(PlannerPriority.allCases, id: \.self) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
            }
        }
        .navigationTitle("New task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(title.trimmingCharacters(in: .whitespacesAndNewlines),
                           dueDate, priority)
                    dismiss()
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

private struct SettingsView: View {
    var body: some View {
        ContentPlaceholderView(
            title: "Settings",
            subtitle: "Manage your LifePilot experience.",
            symbol: "gearshape",
            features: ["Preferences", "Notifications", "Privacy"]
        )
    }
}

private struct ContentPlaceholderView: View {
    let title: String
    let subtitle: String
    let symbol: String
    let features: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.tint)
                    .frame(width: 72, height: 72)
                    .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 22))

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.largeTitle.bold())

                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 18) {
                    ForEach(features, id: \.self) { feature in
                        Label(feature, systemImage: "checkmark.circle")
                            .font(.body)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
            }
            .padding(24)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContentView()
}
