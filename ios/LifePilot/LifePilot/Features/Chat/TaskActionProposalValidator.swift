import Foundation

enum TaskActionProposalValidator {
    static func validate(
        _ proposals: [LifePilotTaskActionProposal],
        existingTasks: [PlannerTask]
    ) -> Bool {
        guard !proposals.isEmpty else { return false }

        let existingIDs = Set(existingTasks.map(\.id))
        var operatedTaskIDs = Set<UUID>()

        for proposal in proposals {
            switch proposal.action {
            case "create":
                guard let title = proposal.title,
                      !title.trimmingCharacters(
                        in: .whitespacesAndNewlines
                      ).isEmpty,
                      proposal.dueDate == nil
                        || parseDate(proposal.dueDate) != nil,
                      proposal.priority.map({
                          PlannerPriority(rawValue: $0) != nil
                      }) ?? true else {
                    return false
                }

            case "edit":
                guard let rawID = proposal.task_id,
                      let id = UUID(uuidString: rawID),
                      existingIDs.contains(id),
                      operatedTaskIDs.insert(id).inserted else {
                    return false
                }

                let hasChanges =
                    proposal.title != nil
                    || proposal.dueDate != nil
                    || proposal.priority != nil

                guard hasChanges,
                      proposal.title.map({
                          !$0.trimmingCharacters(
                              in: .whitespacesAndNewlines
                          ).isEmpty
                      }) ?? true,
                      proposal.dueDate == nil
                        || parseDate(proposal.dueDate) != nil,
                      proposal.priority.map({
                          PlannerPriority(rawValue: $0) != nil
                      }) ?? true else {
                    return false
                }

            case "complete", "delete":
                guard let rawID = proposal.task_id,
                      let id = UUID(uuidString: rawID),
                      existingIDs.contains(id),
                      operatedTaskIDs.insert(id).inserted else {
                    return false
                }

            default:
                return false
            }
        }

        return true
    }

    static func parseDate(_ value: String?) -> Date? {
        guard let value, value.count == 10 else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false

        guard let date = formatter.date(from: value),
              formatter.string(from: date) == value else {
            return nil
        }

        return date
    }
}
