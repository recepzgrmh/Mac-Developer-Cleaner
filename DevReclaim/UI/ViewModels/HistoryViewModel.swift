import Foundation
import Observation

@Observable
class HistoryViewModel {
    var reports: [ExecutionReport] = []
    var isFetching = false
    var lastError: String?
    private(set) var presetNamesById: [String: String] = [:]

    private let audit = AuditLogger()
    private let loader = PresetLoader()

    init() {
        if let presets = try? loader.loadEmbeddedPresets() {
            presetNamesById = Dictionary(uniqueKeysWithValues: presets.map { ($0.id, $0.name) })
        }
    }

    @MainActor
    func fetchHistory() async {
        isFetching = true
        defer { isFetching = false }

        do {
            reports = try await audit.fetchReports().sorted(by: { $0.timestamp > $1.timestamp })
            lastError = nil
        } catch {
            lastError = "Failed to load history: \(error.localizedDescription)"
        }
    }

    func presetDisplayName(for report: ExecutionReport) -> String {
        presetNamesById[report.presetId] ?? report.presetId
    }
}
