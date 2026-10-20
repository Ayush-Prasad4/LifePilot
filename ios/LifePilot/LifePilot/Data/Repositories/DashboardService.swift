import SwiftUI

struct DashboardService: DashboardRepository {
    func fetchTasks() -> [LifeTask] {
        [
            LifeTask(
                title: "Review important documents",
                subtitle: "Keep your paperwork organised",
                dueLabel: "Today",
                symbol: "doc.text",
                priority: .important
            ),
            LifeTask(
                title: "Check upcoming deadlines",
                subtitle: "Stay ahead of your commitments",
                dueLabel: "Tomorrow",
                symbol: "calendar",
                priority: .normal
            )
        ]
    }

    func fetchDocuments() -> [LifeDocument] {
        [
            LifeDocument(
                title: "Personal documents",
                category: "Identity",
                updatedLabel: "Recently added",
                symbol: "person.text.rectangle",
                tint: .blue
            ),
            LifeDocument(
                title: "Financial records",
                category: "Finance",
                updatedLabel: "Your records",
                symbol: "creditcard",
                tint: .green
            ),
            LifeDocument(
                title: "Study documents",
                category: "Education",
                updatedLabel: "Your documents",
                symbol: "graduationcap",
                tint: .purple
            )
        ]
    }
}
