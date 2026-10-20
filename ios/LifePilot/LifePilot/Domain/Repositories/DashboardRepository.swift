import Foundation

protocol DashboardRepository {
    func fetchTasks() -> [LifeTask]
    func fetchDocuments() -> [LifeDocument]
}
