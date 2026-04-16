import Foundation

enum DirectDeleteExecutorError: LocalizedError {
    case targetMissing(path: String)
    case deleteFailed(path: String, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .targetMissing(let path):
            return "Target no longer exists: \(path)"
        case .deleteFailed(let path, let underlying):
            return "Failed to delete \(path): \(underlying.localizedDescription)"
        }
    }
}

/// Permanently deletes paths from disk (no Trash fallback).
final class DirectDeleteExecutor: CleanupExecutorProtocol {
    func execute(for target: ScanTarget, preset: Preset) async throws -> ExecutionReport {
        let path = target.url.path
        guard FileManager.default.fileExists(atPath: path) else {
            throw DirectDeleteExecutorError.targetMissing(path: path)
        }

        do {
            try FileManager.default.removeItem(at: target.url)
        } catch {
            throw DirectDeleteExecutorError.deleteFailed(path: path, underlying: error)
        }

        return ExecutionReport(
            timestamp: Date(),
            presetId: preset.id,
            executionMode: .delete,
            recoveredBytes: target.allocatedSizeInBytes,
            wasSuccess: true,
            errorMessage: nil
        )
    }
}
