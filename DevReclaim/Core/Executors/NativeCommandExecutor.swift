import Foundation

enum ExecutorError: Error {
    case commandNotFoundOrFailed
    case executionFailed(exitCode: Int32, errorString: String)
}

protocol CleanupExecutorProtocol {
    func execute(for target: ScanTarget, preset: Preset) async throws -> ExecutionReport
}

class NativeCommandExecutor: CleanupExecutorProtocol {
    func execute(for target: ScanTarget, preset: Preset) async throws -> ExecutionReport {
        guard let command = preset.nativeCommand else {
            throw ExecutorError.commandNotFoundOrFailed
        }
        
        let process = Process()
        let pipe = Pipe()
        
        // Setup proper environment for developers
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:\(env["PATH"] ?? "")"
        process.environment = env
        
        // Execute via bash
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        if process.terminationStatus != 0 {
            throw ExecutorError.executionFailed(exitCode: process.terminationStatus, errorString: output)
        }
        
        return ExecutionReport(
            timestamp: Date(),
            presetId: preset.id,
            executionMode: .native,
            recoveredBytes: target.allocatedSizeInBytes,
            wasSuccess: true,
            errorMessage: nil
        )
    }
}
