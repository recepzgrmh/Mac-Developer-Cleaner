import Foundation

class TrashExecutor: CleanupExecutorProtocol {
    func execute(for target: ScanTarget, preset: Preset) async throws -> ExecutionReport {
        let fileManager = FileManager.default
        
        // Use macOS trash facility instead of raw deletion
        var resultingURL: NSURL?
        try fileManager.trashItem(at: target.url, resultingItemURL: &resultingURL)
        
        return ExecutionReport(
            timestamp: Date(),
            presetId: preset.id,
            executionMode: .trash,
            recoveredBytes: target.allocatedSizeInBytes,
            wasSuccess: true,
            errorMessage: nil
        )
    }
}
