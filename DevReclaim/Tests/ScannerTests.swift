import XCTest
@testable import DevReclaim

final class ScannerTests: XCTestCase {
    
    var scanner: ScannerService!
    var tempDir: URL!
    
    override func setUp() {
        super.setUp()
        scanner = ScannerService()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }
    
    func testDiscoverGlobalTargets() async throws {
        // Create a dummy global cache folder
        let npmDir = tempDir.appendingPathComponent(".npm")
        try FileManager.default.createDirectory(at: npmDir, withIntermediateDirectories: true)
        
        let preset = Preset(
            id: "npm_test",
            name: "npm Test",
            category: "global_cache",
            pathResolver: npmDir.path,
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
        
        // In tests we should use matchingPreset
        let targets = try await scanner.discoverGlobalTargets(for: preset)
        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets.first?.url.resolvingSymlinksInPath().path, npmDir.resolvingSymlinksInPath().path)
        XCTAssertEqual(targets.first?.matchingPresetId, preset.id)
    }
    
    func testDiscoverProjectTargetsSkipsGit() async throws {
        // Setup:
        // tempDir/
        //   project1/
        //     .git/
        //       build/ (should be skipped because it's inside .git)
        //     build/ (should be found)
        
        let projectDir = tempDir.appendingPathComponent("project1")
        let gitDir = projectDir.appendingPathComponent(".git")
        let gitBuildDir = gitDir.appendingPathComponent("build")
        let validBuildDir = projectDir.appendingPathComponent("build")
        
        try FileManager.default.createDirectory(at: gitBuildDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: validBuildDir, withIntermediateDirectories: true)
        
        let preset = Preset(
            id: "build_test",
            name: "Build Test",
            category: "project_artifact",
            pathResolver: "build",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: nil,
            riskLevel: .usuallySafe,
            reviewReason: nil,
            guardrailRules: [],
            explanation: "Test",
            executionType: .trash,
            nativeCommand: nil,
            fallbackAction: .none
        )
        
        let targets = try await scanner.discoverProjectTargets(in: projectDir, for: preset)
        
        XCTAssertEqual(targets.count, 1, "Should only find one build directory")
        XCTAssertEqual(targets.first?.url.resolvingSymlinksInPath().path, validBuildDir.resolvingSymlinksInPath().path)
    }
    
    func testCalculateVolume() async throws {
        let testDir = tempDir.appendingPathComponent("measure_test")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        
        let file1 = testDir.appendingPathComponent("file1.txt")
        let data = Data(repeating: 0, count: 1024) // 1KB
        try data.write(to: file1)
        
        let volume = try await scanner.calculateVolume(for: testDir)
        
        // Allocated size might be larger than 1024 due to block size, but should be at least 1024.
        XCTAssertGreaterThanOrEqual(volume, 1024)
    }
}
