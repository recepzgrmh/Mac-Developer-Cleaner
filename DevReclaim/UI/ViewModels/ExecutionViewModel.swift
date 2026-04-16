import Foundation
import Observation

@Observable
class ExecutionViewModel {
    enum ExecutionState: Equatable {
        case idle
        case runningNative
        case failedWaitingForTrashConsent(ScanTarget)
        case runningTrash
        case completed(recoveredBytes: Int64)
        case error(String)
        
        static func == (lhs: ExecutionState, rhs: ExecutionState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.runningNative, .runningNative): return true
            case (.runningTrash, .runningTrash): return true
            case (.failedWaitingForTrashConsent(let lTarget), .failedWaitingForTrashConsent(let rTarget)):
                return lTarget.url == rTarget.url
            case (.completed(let lBytes), .completed(let rBytes)):
                return lBytes == rBytes
            case (.error(let lMsg), .error(let rMsg)):
                return lMsg == rMsg
            default: return false
            }
        }
    }
    
    var state: ExecutionState = .idle
    var logMessage: String = ""
    
    private let nativeExecutor = NativeCommandExecutor()
    private let trashExecutor = TrashExecutor()
    private let audit = AuditLogger()
    
    @MainActor
    func execute(target: ScanTarget) async {
        guard let preset = target.matchingPreset else {
            state = .error("No matching preset found for target.")
            return
        }
        
        state = .runningNative
        logMessage = "Running native clean command for \(preset.name)..."
        
        do {
            let report = try await nativeExecutor.execute(for: target, preset: preset)
            try await audit.logAction(report: report)
            state = .completed(recoveredBytes: report.recoveredBytes)
            logMessage = "Success! Recovered \(report.recoveredBytes / 1_000_000) MB."
        } catch {
            logMessage = "Native command failed: \(error.localizedDescription)"
            if preset.fallbackAction == .prompt_for_trash {
                state = .failedWaitingForTrashConsent(target)
            } else {
                state = .error("Native cleanup failed and no fallback is configured.")
            }
        }
    }
    
    @MainActor
    func executeTrashFallback(target: ScanTarget) async {
        guard let preset = target.matchingPreset else { return }
        
        state = .runningTrash
        logMessage = "Running Trash fallback for \(preset.name)..."
        
        do {
            let report = try await trashExecutor.execute(for: target, preset: preset)
            try await audit.logAction(report: report)
            state = .completed(recoveredBytes: report.recoveredBytes)
            logMessage = "Success via Trash! Recovered \(report.recoveredBytes / 1_000_000) MB."
        } catch {
            state = .error("Trash fallback failed: \(error.localizedDescription)")
            logMessage = "Trash Error: \(error.localizedDescription)"
        }
    }
}
