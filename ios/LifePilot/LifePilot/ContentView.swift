import SwiftUI
import UIKit
import UserNotifications

struct ContentView: View {
    init() {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset-tasks") {
            UserDefaults.standard.removeObject(forKey: "lifepilot.planner.tasks")
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-corrupt-task-storage") {
            UserDefaults.standard.set(
                Data("invalid task data".utf8),
                forKey: "lifepilot.planner.tasks"
            )
        }
    }

    @Environment(\.scenePhase) private var scenePhase
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
        .onAppear {
            TaskReminderManager.shared.reconcile(CalendarTaskStore().load())
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            TaskReminderManager.shared.reconcile(CalendarTaskStore().load())
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
        loadIfValid() ?? []
    }

    func loadIfValid() -> [PlannerTask]? {
        guard let data = defaults.data(forKey: key) else { return [] }
        return try? JSONDecoder().decode([PlannerTask].self, from: data)
    }

    @discardableResult
    func save(_ tasks: [PlannerTask]) -> Bool {
        // Never overwrite existing task data if it cannot be decoded.
        if let existingData = defaults.data(forKey: key),
           (try? JSONDecoder().decode([PlannerTask].self, from: existingData)) == nil {
            return false
        }

        guard let data = try? JSONEncoder().encode(tasks) else {
            return false
        }
        defaults.set(data, forKey: key)
        return true
    }
}

final class TaskReminderManager {
    static let shared = TaskReminderManager()
    private let center = UNUserNotificationCenter.current()

    private init() {}

    static func shouldScheduleReminder(
        for task: PlannerTask,
        at date: Date = Date()
    ) -> Bool {
        !task.isCompleted && task.dueDate > date
    }

    func schedule(_ task: PlannerTask) {
        cancel(task)
        guard Self.shouldScheduleReminder(for: task) else { return }

        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if granted { self.enqueue(task) }
                }
            case .authorized, .provisional, .ephemeral:
                self.enqueue(task)
            default:
                break
            }
        }
    }

    func reconcile(_ tasks: [PlannerTask]) {
        center.getNotificationSettings { settings in
            let notificationsAllowed: Bool
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                notificationsAllowed = true
            default:
                notificationsAllowed = false
            }

            for task in tasks {
                guard Self.shouldScheduleReminder(for: task) else {
                    self.cancel(task)
                    continue
                }

                // Reconciliation never prompts for notification permission.
                // Adding the same stable identifier refreshes, rather than duplicates, a request.
                if notificationsAllowed {
                    self.enqueue(task)
                }
            }
        }
    }

    func syncChanges(from oldTasks: [PlannerTask], to newTasks: [PlannerTask]) {
        let oldByID = Dictionary(uniqueKeysWithValues: oldTasks.map { ($0.id, $0) })
        let newByID = Dictionary(uniqueKeysWithValues: newTasks.map { ($0.id, $0) })

        for oldTask in oldTasks where newByID[oldTask.id] == nil {
            cancel(oldTask)
        }

        for task in newTasks {
            guard oldByID[task.id] != task else { continue }

            if task.isCompleted {
                cancel(task)
            } else {
                schedule(task)
            }
        }
    }

    func cancel(_ task: PlannerTask) {
        let id = task.id.uuidString
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }

    private func enqueue(_ task: PlannerTask) {
        guard Self.shouldScheduleReminder(for: task) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Task due"
        content.body = task.title
        content.sound = .default

        let parts = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: task.dueDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        center.add(
            UNNotificationRequest(
                identifier: task.id.uuidString,
                content: content,
                trigger: trigger
            )
        )
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
    @State private var showingSaveError = false

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
                    var updatedTasks = tasks
                    updatedTasks.removeAll { $0.id == task.id }
                    if persist(updatedTasks) {
                        TaskReminderManager.shared.cancel(task)
                    }
                }
                taskPendingDeletion = nil
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Couldn't Save Task", isPresented: $showingSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your calendar changes could not be saved. Existing task data was preserved. Please try again after resolving the storage issue.")
        }
        .onAppear {
            refreshTasksFromStorage()
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
                    var updatedTasks = tasks
                    let savedTask: PlannerTask

                    if let existing = editingTask,
                       let index = updatedTasks.firstIndex(where: { $0.id == existing.id }) {
                        updatedTasks[index].title = title
                        updatedTasks[index].dueDate = date
                        updatedTasks[index].priority = priority
                        savedTask = updatedTasks[index]
                    } else {
                        let item = PlannerTask(title: title, dueDate: date, priority: priority)
                        updatedTasks.append(item)
                        savedTask = item
                    }

                    guard persist(updatedTasks, showError: false) else { return false }
                    TaskReminderManager.shared.schedule(savedTask)
                    return true
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

    private func refreshTasksFromStorage() {
        guard let latestTasks = CalendarTaskStore().loadIfValid() else { return }
        tasks = latestTasks
    }

    private func update(_ task: PlannerTask, change: (inout PlannerTask) -> Void) {
        var updatedTasks = tasks
        guard let index = updatedTasks.firstIndex(where: { $0.id == task.id }) else { return }
        change(&updatedTasks[index])
        guard persist(updatedTasks) else { return }

        if updatedTasks[index].isCompleted {
            TaskReminderManager.shared.cancel(updatedTasks[index])
        } else {
            TaskReminderManager.shared.schedule(updatedTasks[index])
        }
    }

    @discardableResult
    private func persist(
        _ updatedTasks: [PlannerTask],
        showError: Bool = true
    ) -> Bool {
        guard CalendarTaskStore().save(updatedTasks) else {
            if showError { showingSaveError = true }
            return false
        }
        tasks = updatedTasks
        return true
    }
}

private struct PlannerTaskEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingSaveError = false
    @State private var title: String
    @State private var dueDate: Date
    @State private var priority: PlannerPriority

    let task: PlannerTask?
    let onSave: (String, Date, PlannerPriority) -> Bool

    init(task: PlannerTask? = nil, onSave: @escaping (String, Date, PlannerPriority) -> Bool) {
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
                .accessibilityIdentifier("taskPriorityPicker")
            }
        }
        .alert("Couldn't Save Task", isPresented: $showingSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your calendar changes could not be saved. Existing task data was preserved. Please try again after resolving the storage issue.")
        }
        .navigationTitle(task == nil ? "New task" : "Edit task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if onSave(title.trimmingCharacters(in: .whitespacesAndNewlines), dueDate, priority) {
                        dismiss()
                    } else {
                        showingSaveError = true
                    }
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
