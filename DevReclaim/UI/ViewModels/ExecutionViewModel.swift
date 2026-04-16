import Foundation
import Observation

@Observable
class ExecutionViewModel {
    enum ExecutionState: Equatable {
        case idle
        case runningDelete
        case completed(ExecutionReport)
        case failed(String)

        static func == (lhs: ExecutionState, rhs: ExecutionState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.runningDelete, .runningDelete): return true
            case (.completed(let l), .completed(let r)): return l.id == r.id
            case (.failed(let l), .failed(let r)): return l == r
            default: return false
            }
        }
    }

    var state: ExecutionState = .idle
    var userFacingStatus: String = ""
    var technicalDetails: String = ""
    var lastExecutionReport: ExecutionReport?
    /// Actual disk space freed (difference in available volume before/after execution).
    var freedDiskBytes: Int64 = 0

    private let deleteExecutor = DirectDeleteExecutor()
    private let audit = AuditLogger()

    @MainActor
    func execute(target: ScanTarget, preset: Preset) async {
        // Block only while an execution is actively in-flight.
        guard state != .runningDelete else {
            userFacingStatus = "A cleanup is already in progress. Please wait."
            return
        }

        // Stale-state guard — the target may have been deleted since the last scan.
        guard FileManager.default.fileExists(atPath: target.url.path) else {
            state = .failed("Target no longer exists.")
            userFacingStatus = "The target was already removed since the last scan. Please re-scan."
            technicalDetails = "Path not found: \(target.url.path)"
            return
        }

        // Clear results from any previous execution before starting fresh.
        freedDiskBytes = 0
        technicalDetails = ""

        let spaceBefore = availableDiskSpace()

        state = .runningDelete
        userFacingStatus = "Permanently deleting \(preset.name)…"
        technicalDetails = "Deleting path: \(target.url.path)"

        do {
            let report = try await deleteExecutor.execute(for: target, preset: preset)
            try await audit.logAction(report: report)
            lastExecutionReport = report

            freedDiskBytes = max(0, availableDiskSpace() - spaceBefore)
            state = .completed(report)

            let reclaimed = ByteCountFormatter.string(fromByteCount: report.recoveredBytes, countStyle: .file)
            let freed = ByteCountFormatter.string(fromByteCount: freedDiskBytes, countStyle: .file)
            userFacingStatus = "Permanently deleted. Reclaimed \(reclaimed). Disk freed: \(freed)."
            technicalDetails = "Permanent delete completed successfully."
        } catch {
            let userMessage = userFacingMessage(for: error)
            state = .failed(userMessage)
            userFacingStatus = userMessage
            technicalDetails = "Permanent delete error: \(error.localizedDescription)"
        }
    }

    func reset() {
        state = .idle
        userFacingStatus = ""
        technicalDetails = ""
        freedDiskBytes = 0
    }

    // MARK: - Helpers

    private func availableDiskSpace() -> Int64 {
        guard let values = try? URL(fileURLWithPath: NSHomeDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let capacity = values.volumeAvailableCapacityForImportantUsage else {
            return 0
        }
        return capacity
    }

    private func userFacingMessage(for error: Error) -> String {
        let nsError = error as NSError
        let permissionCodes: Set<Int> = [
            NSFileReadNoPermissionError,
            NSFileWriteNoPermissionError,
            NSFileWriteVolumeReadOnlyError
        ]

        if nsError.domain == NSCocoaErrorDomain && permissionCodes.contains(nsError.code) {
            return "Cleanup failed: permission denied. Grant Full Disk Access and try again."
        }
        return "Cleanup failed: \(error.localizedDescription)"
    }
}
