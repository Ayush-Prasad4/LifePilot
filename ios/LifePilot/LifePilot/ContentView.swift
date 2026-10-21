import SwiftUI
import UIKit
import UserNotifications

struct ContentView: View {
    init() {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset-tasks") {
            UserDefaults.standard.removeObject(forKey: "lifepilot.planner.tasks")
        }
    }

    @State private var selectedTab = ProcessInfo.processInfo.arguments.contains("-ui-testing-calendar") ? 4 : 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(
                onAddDocument: { selectedTab = 1 },
                onAskAI: { selectedTab = 3 }
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
                GeneralChatView()
            }
            .tabItem {
                Label("Chat", systemImage: "bubble.left.and.bubble.right")
            }
            .tag(3)

            NavigationStack {
                CalendarView()
            }
            .tabItem {
                Label("Calendar", systemImage: "calendar")
            }
            .tag(4)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(5)
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

final class TaskReminderManager {
    static let shared = TaskReminderManager()
    private let center = UNUserNotificationCenter.current()
    private init() {}
    func schedule(_ task: PlannerTask) {
        cancel(task)
        guard !task.isCompleted, task.dueDate > Date() else { return }
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if granted { self.enqueue(task) }
                }
            case .authorized, .provisional, .ephemeral: self.enqueue(task)
            default: break
            }
        }
    }
    func cancel(_ task: PlannerTask) {
        let id = task.id.uuidString
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }
    private func enqueue(_ task: PlannerTask) {
        guard !task.isCompleted, task.dueDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Task due"
        content.body = task.title
        content.sound = .default
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: task.dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        center.add(UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger))
    }
}

private enum PlannerFilter: String, CaseIterable {
    case today = "Today"
    case upcoming = "Upcoming"
    case completed = "Completed"
    case all = "All"
}

private struct CalendarView: View {
    @State private var tasks = CalendarTaskStore().load()
    @State private var showingEditor = false
    @State private var editingTask: PlannerTask?
    @State private var taskPendingDeletion: PlannerTask?
    @State private var showingDeleteConfirmation = false
    @State private var taskForActions: PlannerTask? = nil
    @State private var filter: PlannerFilter = .today
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())

    private var visibleTasks: [PlannerTask] {
        let calendar = Calendar.current
        let filtered = tasks.filter { task in
            switch filter {
            case .today:
                return calendar.isDate(task.dueDate, inSameDayAs: selectedDate)
                    && !task.isCompleted
            case .upcoming:
                return task.dueDate >= calendar.startOfDay(for: Date())
                    && !task.isCompleted
            case .completed:
                return task.isCompleted
            case .all:
                return true
            }
        }
        return filtered.sorted {
            if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
            return $0.dueDate < $1.dueDate
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Filter tasks", selection: $filter) {
                    ForEach(PlannerFilter.allCases, id: \.self) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                if filter == .today {
                    DatePicker("Selected day", selection: $selectedDate, displayedComponents: .date)
                }

                HStack {
                    summary("Open", value: tasks.filter { !$0.isCompleted }.count)
                    Spacer()
                    summary("Completed", value: tasks.filter(\.isCompleted).count)
                }
                .padding(.vertical, 6)
            }

            Section(filter.rawValue) {
                if visibleTasks.isEmpty {
                    ContentUnavailableView(
                        "No tasks here",
                        systemImage: "calendar",
                        description: Text("Add a task or choose another filter.")
                    )
                }

                ForEach(visibleTasks) { task in
                    HStack(spacing: 12) {
                        Button {
                            update(task) { $0.isCompleted.toggle() }
                        } label: {
                            Image(systemName: task.isCompleted
                                  ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(task.isCompleted ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(task.isCompleted ? "Mark incomplete" : "Complete task")

                        VStack(alignment: .leading, spacing: 5) {
                            Text(task.title)
                                .font(.body.weight(.medium))
                                .strikethrough(task.isCompleted)
                                .accessibilityIdentifier(task.title)

                            Text(task.dueDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(isOverdue(task) ? .red : .secondary)

                            if isOverdue(task) {
                                Text("Overdue")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.red)
                            }
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
                    .contentShape(Rectangle())
                    Button {
                        taskForActions = task
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Task actions")
                    .accessibilityIdentifier("Task actions")
                    .buttonStyle(.borderless)
                }
            }
        }
        .confirmationDialog(
            "Task actions",
            isPresented: Binding(
                get: { taskForActions != nil },
                set: { if !$0 { taskForActions = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Edit") {
                editingTask = taskForActions
                showingEditor = true
                taskForActions = nil
            }
            Button(taskForActions?.isCompleted == true ? "Mark Incomplete" : "Complete") {
                if let task = taskForActions {
                    update(task) { $0.isCompleted.toggle() }
                }
                taskForActions = nil
            }
            Button("Delete", role: .destructive) {
                taskPendingDeletion = taskForActions
                taskForActions = nil
                showingDeleteConfirmation = taskPendingDeletion != nil
            }
            Button("Cancel", role: .cancel) {
                taskForActions = nil
            }
        }
        .alert("Delete this task?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                taskPendingDeletion = nil
            }
            Button("Delete", role: .destructive) {
                if let task = taskPendingDeletion {
                    TaskReminderManager.shared.cancel(task)
                    tasks.removeAll { $0.id == task.id }
                    persist()
                }
                taskPendingDeletion = nil
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .navigationTitle("Calendar")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingTask = nil
                    showingEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add task")
            }
        }
        .sheet(isPresented: $showingEditor, onDismiss: { editingTask = nil }) {
            NavigationStack {
                PlannerTaskEditor(task: editingTask) { title, date, priority in
                    if let existing = editingTask,
                       let index = tasks.firstIndex(where: { $0.id == existing.id }) {
                        tasks[index].title = title
                        tasks[index].dueDate = date
                        tasks[index].priority = priority
                        TaskReminderManager.shared.schedule(tasks[index])
                    } else {
                        let item = PlannerTask(title: title, dueDate: date, priority: priority)
                        tasks.append(item)
                        TaskReminderManager.shared.schedule(item)
                    }
                    persist()
                }
            }
        }
    }

    private func summary(_ title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)").font(.title2.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func priorityColor(_ priority: PlannerPriority) -> Color {
        switch priority {
        case .normal: .blue
        case .important: .orange
        case .urgent: .red
        }
    }

    private func isOverdue(_ task: PlannerTask) -> Bool {
        !task.isCompleted && task.dueDate < Date()
            && !Calendar.current.isDateInToday(task.dueDate)
    }

    private func update(_ task: PlannerTask, change: (inout PlannerTask) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        change(&tasks[index])
        if tasks[index].isCompleted { TaskReminderManager.shared.cancel(tasks[index]) } else { TaskReminderManager.shared.schedule(tasks[index]) }
        persist()
    }

    private func persist() {
        CalendarTaskStore().save(tasks)
    }
}

private struct PlannerTaskEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var dueDate: Date
    @State private var priority: PlannerPriority

    let task: PlannerTask?
    let onSave: (String, Date, PlannerPriority) -> Void

    init(task: PlannerTask? = nil, onSave: @escaping (String, Date, PlannerPriority) -> Void) {
        self.task = task
        self.onSave = onSave
        _title = State(initialValue: task?.title ?? "")
        _dueDate = State(initialValue: task?.dueDate ?? Date())
        _priority = State(initialValue: task?.priority ?? .normal)
    }

    var body: some View {
        Form {
            Section("Task details") {
                TextField("What do you need to do?", text: $title)
                DatePicker("Due date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                Picker("Priority", selection: $priority) {
                    ForEach(PlannerPriority.allCases, id: \.self) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
            }
        }
        .navigationTitle(task == nil ? "New task" : "Edit task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(title.trimmingCharacters(in: .whitespacesAndNewlines), dueDate, priority)
                    dismiss()
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

private struct SettingsView: View {
    @State private var notificationStatus = "Checking…"

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.tint)
                        .frame(width: 52, height: 52)
                        .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("LifePilot")
                            .font(.title3.bold())
                        Text("Your personal productivity space")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Notifications") {
                HStack {
                    Label("Task reminders", systemImage: "bell.badge")
                    Spacer()
                    Text(notificationStatus)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }

                Button {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                } label: {
                    Label("Open iOS Settings", systemImage: "arrow.up.right.square")
                }

                Text("Task reminders are delivered at the task's due time when notifications are permitted. You can change permission in iOS Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Label("Documents stay in app storage", systemImage: "lock.shield")
                    .font(.body)

                Text("Imported PDF files are stored in LifePilot's local app storage. When you explicitly use AI document features, relevant text and your question may be sent to the configured AI service to generate an answer.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("You can manage notification permissions in iOS Settings. Removing the app may remove its locally stored files and data.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Platform", value: "iOS")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refreshNotificationStatus)
    }

    private func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status: String
            switch settings.authorizationStatus {
            case .authorized:
                status = "Allowed"
            case .denied:
                status = "Denied"
            case .notDetermined:
                status = "Not requested"
            case .provisional:
                status = "Provisional"
            case .ephemeral:
                status = "Temporary"
            @unknown default:
                status = "Unknown"
            }

            DispatchQueue.main.async {
                notificationStatus = status
            }
        }
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
