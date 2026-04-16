import Foundation

protocol AuditLoggerProtocol {
    func logAction(report: ExecutionReport) async throws
    func fetchReports() async throws -> [ExecutionReport]
}

class AuditLogger: AuditLoggerProtocol {
    private let logURL: URL
    
    init(logURL: URL? = nil) {
        if let customURL = logURL {
            self.logURL = customURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appDir = appSupport.appendingPathComponent("DevReclaim")
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
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
        if let data = try? Data(contentsOf: logURL) {
            return (try? JSONDecoder().decode([ExecutionReport].self, from: data)) ?? []
        }
        return []
    }
}
