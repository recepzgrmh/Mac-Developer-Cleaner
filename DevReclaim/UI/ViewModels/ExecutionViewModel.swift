import Foundation
import Observation

@Observable
class ExecutionViewModel {
    enum ExecutionState: Equatable {
        case idle
        case runningNative
        case awaitingTrashConsent(ScanTarget)
        case runningTrash
        case completed(ExecutionReport)
        case failed(String)

        static func == (lhs: ExecutionState, rhs: ExecutionState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.runningNative, .runningNative): return true
            case (.runningTrash, .runningTrash): return true
            case (.awaitingTrashConsent(let l), .awaitingTrashConsent(let r)): return l.url == r.url
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

    private let nativeExecutor = NativeCommandExecutor()
    private let trashExecutor = TrashExecutor()
    private let audit = AuditLogger()

    @MainActor
    func execute(target: ScanTarget, preset: Preset) async {
        // Concurrent execution guard — do not interrupt an in-flight operation.
        guard case .idle = state else {
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

        state = .runningNative
        userFacingStatus = "Running native clean command for \(preset.name)..."
        technicalDetails = "Executing: \(preset.nativeCommand ?? "n/a")"

        let spaceBefore = availableDiskSpace()

        do {
            let report = try await nativeExecutor.execute(for: target, preset: preset)
            try await audit.logAction(report: report)
            lastExecutionReport = report

            freedDiskBytes = max(0, availableDiskSpace() - spaceBefore)
            state = .completed(report)

            let reclaimed = ByteCountFormatter.string(fromByteCount: report.recoveredBytes, countStyle: .file)
            let freed = ByteCountFormatter.string(fromByteCount: freedDiskBytes, countStyle: .file)
            userFacingStatus = "Reclaimed \(reclaimed). Disk freed: \(freed)."
            technicalDetails = "Native execution completed successfully."
        } catch {
            technicalDetails = "Native command failed: \(error.localizedDescription)"
            if preset.fallbackAction == .prompt_for_trash {
                state = .awaitingTrashConsent(target)
                userFacingStatus = "Native cleanup failed. Move to Trash instead?"
            } else {
                state = .failed("Native cleanup failed and no fallback is configured.")
                userFacingStatus = "Cleanup failed."
            }
        }
    }

    @MainActor
    func executeTrashFallback(target: ScanTarget, preset: Preset) async {
        // Stale-state guard for trash fallback path as well.
        guard FileManager.default.fileExists(atPath: target.url.path) else {
            state = .failed("Target no longer exists.")
            userFacingStatus = "The target was already removed. Please re-scan."
            return
        }

        state = .runningTrash
        userFacingStatus = "Moving \(preset.name) items to Trash..."
        technicalDetails = "Attempting Trash fallback for: \(target.url.path)"

        let spaceBefore = availableDiskSpace()

        do {
            let report = try await trashExecutor.execute(for: target, preset: preset)
            try await audit.logAction(report: report)
            lastExecutionReport = report

            freedDiskBytes = max(0, availableDiskSpace() - spaceBefore)
            state = .completed(report)

            let reclaimed = ByteCountFormatter.string(fromByteCount: report.recoveredBytes, countStyle: .file)
            let freed = ByteCountFormatter.string(fromByteCount: freedDiskBytes, countStyle: .file)
            userFacingStatus = "Moved to Trash. Reclaimed \(reclaimed). Disk freed: \(freed)."
            technicalDetails = "Trash fallback completed successfully."
        } catch {
            state = .failed("Trash fallback failed: \(error.localizedDescription)")
            userFacingStatus = "Cleanup failed."
            technicalDetails = "Trash Error: \(error.localizedDescription)"
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
}
