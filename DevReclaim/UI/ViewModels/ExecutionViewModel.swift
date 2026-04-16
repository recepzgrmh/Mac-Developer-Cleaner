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
            case (.awaitingTrashConsent(let lTarget), .awaitingTrashConsent(let rTarget)):
                return lTarget.url == rTarget.url
            case (.completed(let lReport), .completed(let rReport)):
                return lReport.id == rReport.id
            case (.failed(let lMsg), .failed(let rMsg)):
                return lMsg == rMsg
            default: return false
            }
        }
    }
    
    var state: ExecutionState = .idle
    var userFacingStatus: String = ""
    var technicalDetails: String = ""
    var lastExecutionReport: ExecutionReport?
    
    private let nativeExecutor = NativeCommandExecutor()
    private let trashExecutor = TrashExecutor()
    private let audit = AuditLogger()
    
    @MainActor
    func execute(target: ScanTarget, preset: Preset) async {
        state = .runningNative
        userFacingStatus = "Running native clean command for \(preset.name)..."
        technicalDetails = "Executing: \(preset.nativeCommand ?? "n/a")"
        
        do {
            let report = try await nativeExecutor.execute(for: target, preset: preset)
            try await audit.logAction(report: report)
            lastExecutionReport = report
            state = .completed(report)
            
            let sizeStr = ByteCountFormatter.string(fromByteCount: report.recoveredBytes, countStyle: .file)
            userFacingStatus = "Success! Recovered \(sizeStr)."
            technicalDetails = "Native execution completed successfully."
        } catch {
            technicalDetails = "Native command failed: \(error.localizedDescription)"
            if preset.fallbackAction == .prompt_for_trash {
                state = .awaitingTrashConsent(target)
                userFacingStatus = "Native cleanup failed. Would you like to try moving to Trash?"
            } else {
                state = .failed("Native cleanup failed and no fallback is configured.")
                userFacingStatus = "Cleanup failed."
            }
        }
    }
    
    @MainActor
    func executeTrashFallback(target: ScanTarget, preset: Preset) async {
        state = .runningTrash
        userFacingStatus = "Moving \(preset.name) items to Trash..."
        technicalDetails = "Attempting Trash fallback for: \(target.url.path)"
        
        do {
            let report = try await trashExecutor.execute(for: target, preset: preset)
            try await audit.logAction(report: report)
            lastExecutionReport = report
            state = .completed(report)
            
            let sizeStr = ByteCountFormatter.string(fromByteCount: report.recoveredBytes, countStyle: .file)
            userFacingStatus = "Success via Trash! Recovered \(sizeStr)."
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
    }
}
