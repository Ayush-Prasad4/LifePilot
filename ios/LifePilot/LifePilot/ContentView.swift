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

private struct CalendarView: View {
    var body: some View {
        ContentPlaceholderView(
            title: "Calendar",
            subtitle: "Keep track of upcoming events and deadlines.",
            symbol: "calendar",
            features: ["View upcoming events", "Track deadlines", "Plan your schedule"]
        )
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
