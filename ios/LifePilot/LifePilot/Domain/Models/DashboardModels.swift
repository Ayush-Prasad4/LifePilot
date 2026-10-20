import SwiftUI

struct LifeTask: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let dueLabel: String
    let symbol: String
    let priority: TaskPriority

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        dueLabel: String,
        symbol: String,
        priority: TaskPriority
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.dueLabel = dueLabel
        self.symbol = symbol
        self.priority = priority
    }
}

enum TaskPriority {
    case normal
    case important
}

struct LifeDocument: Identifiable {
    let id: UUID
    let title: String
    let category: String
    let updatedLabel: String
    let symbol: String
    let tint: Color

    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        updatedLabel: String,
        symbol: String,
        tint: Color
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.updatedLabel = updatedLabel
        self.symbol = symbol
        self.tint = tint
    }
}
