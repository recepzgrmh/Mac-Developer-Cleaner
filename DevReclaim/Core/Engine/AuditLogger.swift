import Foundation
import OSLog

protocol AuditLoggerProtocol {
    func logAction(report: ExecutionReport) async throws
    func fetchReports() async throws -> [ExecutionReport]
}

class AuditLogger: AuditLoggerProtocol {
    private let logURL: URL
    private let logger = Logger(subsystem: "DevReclaim", category: "AuditLogger")
    
    init(logURL: URL? = nil) {
        if let customURL = logURL {
            self.logURL = customURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appDir = appSupport.appendingPathComponent("DevReclaim")
            do {
                try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
            } catch {
                logger.error("Failed to create audit directory: \(error.localizedDescription)")
            }
            self.logURL = appDir.appendingPathComponent("audit-log.json")
        }
    }
    
    func logAction(report: ExecutionReport) async throws {
        var existingReports = try await fetchReports()
        existingReports.append(report)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let newData = try encoder.encode(existingReports)
        
        try newData.write(to: logURL, options: .atomic)
    }
    
    func fetchReports() async throws -> [ExecutionReport] {
        do {
            let data = try Data(contentsOf: logURL)
            return try JSONDecoder().decode([ExecutionReport].self, from: data)
        } catch CocoaError.fileReadNoSuchFile {
            return []
        } catch {
            logger.error("Failed to read audit log: \(error.localizedDescription)")
            throw error
        }
    }
}
