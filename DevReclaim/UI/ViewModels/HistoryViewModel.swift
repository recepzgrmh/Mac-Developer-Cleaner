import Foundation
import Observation

@Observable
class HistoryViewModel {
    var reports: [ExecutionReport] = []
    var isFetching = false
    
    private let audit = AuditLogger()
    
    @MainActor
    func fetchHistory() async {
        isFetching = true
        do {
            self.reports = try await audit.fetchReports().sorted(by: { $0.timestamp > $1.timestamp })
        } catch {
            print("History load error: \(error)")
        }
        isFetching = false
    }
}
