import XCTest
@testable import DevReclaim

final class ExecutorTests: XCTestCase {
    
    var tempDir: URL!
    
    override func setUp() {
        super.setUp()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }
    
    func testNativeCommandExecutorSuccess() async throws {
        let executor = NativeCommandExecutor()
        
        let testFile = tempDir.appendingPathComponent("test.txt")
        try "test".write(to: testFile, atomically: true, encoding: .utf8)
        
        let preset = Preset(
            id: "test_preset",
            name: "Test",
            category: "test",
            pathResolver: "",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.native],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: nil,
            riskLevel: .safe,
            reviewReason: nil,
            guardrailRules: [],
            explanation: "Test",
            executionType: .native,
            nativeCommand: "rm \(testFile.path)",
            fallbackAction: .none
        )
        let target = ScanTarget(url: testFile, matchingPreset: preset, allocatedSizeInBytes: 100)
        
        let report = try await executor.execute(for: target, preset: preset)
        
        XCTAssertTrue(report.wasSuccess)
        XCTAssertFalse(FileManager.default.fileExists(atPath: testFile.path))
    }
    
    func testNativeCommandExecutorFailure() async throws {
        let executor = NativeCommandExecutor()
        let preset = Preset(
            id: "test_preset",
            name: "Test",
            category: "test",
            pathResolver: "",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.native],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: nil,
            riskLevel: .safe,
            reviewReason: nil,
            guardrailRules: [],
            explanation: "Test",
            executionType: .native,
            nativeCommand: "non_existent_command_12345",
            fallbackAction: .none
        )
        let target = ScanTarget(url: tempDir, matchingPreset: preset, allocatedSizeInBytes: 100)
        
        do {
            _ = try await executor.execute(for: target, preset: preset)
            XCTFail("Should have thrown an error")
        } catch {
            // Success
        }
    }
    
    func testTrashExecutor() async throws {
        let executor = TrashExecutor()
        
        let testFile = tempDir.appendingPathComponent("test_trash.txt")
        try "test".write(to: testFile, atomically: true, encoding: .utf8)
        
        let preset = Preset(
            id: "test_preset",
            name: "Test",
            category: "test",
            pathResolver: "",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: nil,
            riskLevel: .safe,
            reviewReason: nil,
            guardrailRules: [],
            explanation: "Test",
            executionType: .trash,
            nativeCommand: nil,
            fallbackAction: .none
        )
        let target = ScanTarget(url: testFile, matchingPreset: preset, allocatedSizeInBytes: 100)
        
        let report = try await executor.execute(for: target, preset: preset)
        
        XCTAssertTrue(report.wasSuccess)
        XCTAssertFalse(FileManager.default.fileExists(atPath: testFile.path))
        // Note: We can't easily check the trash content in a unit test without complex logic,
        // but checking that it's gone from the original path is a good start.
    }
    
    func testAuditLogger() async throws {
        let logger = AuditLogger()
        let report = ExecutionReport(
            presetId: "test_preset",
            executionMode: .native,
            recoveredBytes: 1024,
            wasSuccess: true
        )
        
        try await logger.logAction(report: report)
        
        // Verify file exists and contains the report
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let logURL = appSupport.appendingPathComponent("DevReclaim/audit-log.json")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: logURL.path))
        
        let data = try Data(contentsOf: logURL)
        let reports = try JSONDecoder().decode([ExecutionReport].self, from: data)
        
        XCTAssertEqual(reports.count, 1)
        XCTAssertEqual(reports.first?.presetId, "test_preset")
    }
}
