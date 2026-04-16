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

    func testDiscoverProjectTargetsBatchForMultiplePresets() async throws {
        let projectA = tempDir.appendingPathComponent("project_a")
        let projectB = tempDir.appendingPathComponent("project_b")
        let artifactNameA = "artifact_a_\(UUID().uuidString)"
        let artifactNameB = "artifact_b_\(UUID().uuidString)"
        let artifactDirA = projectA.appendingPathComponent(artifactNameA)
        let artifactDirB = projectB.appendingPathComponent(artifactNameB)
        try FileManager.default.createDirectory(at: artifactDirA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: artifactDirB, withIntermediateDirectories: true)

        let nodePreset = Preset(
            id: "node_modules_test",
            name: "Node Modules",
            category: "project_artifact",
            pathResolver: artifactNameA,
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: nil,
            riskLevel: .reviewFirst,
            reviewReason: nil,
            guardrailRules: [],
            explanation: "Test",
            executionType: .trash,
            nativeCommand: nil,
            fallbackAction: .none
        )

        let buildPreset = Preset(
            id: "build_test",
            name: "Build",
            category: "project_artifact",
            pathResolver: artifactNameB,
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

        let envKey = "DEVRECLAIM_PROJECT_ROOTS"
        let previousEnv = ProcessInfo.processInfo.environment[envKey]
        setenv(envKey, tempDir.path, 1)
        defer {
            if let previousEnv {
                setenv(envKey, previousEnv, 1)
            } else {
                unsetenv(envKey)
            }
        }

        let results = try await scanner.discoverProjectTargets(for: [nodePreset, buildPreset])

        XCTAssertEqual(results[nodePreset.id]?.count, 1)
        XCTAssertEqual(results[buildPreset.id]?.count, 1)
        XCTAssertEqual(
            results[nodePreset.id]?.first?.url.resolvingSymlinksInPath().path,
            artifactDirA.resolvingSymlinksInPath().path
        )
        XCTAssertEqual(
            results[buildPreset.id]?.first?.url.resolvingSymlinksInPath().path,
            artifactDirB.resolvingSymlinksInPath().path
        )
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

    func testDiscoverSystemTargets() async throws {
        let cacheDir = tempDir.appendingPathComponent("system_cache")
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let preset = Preset(
            id: "system_cache_test",
            name: "System Cache Test",
            category: "system_cache",
            pathResolver: cacheDir.path,
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

        let targets = try await scanner.discoverSystemTargets(for: preset)
        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets.first?.url.path, cacheDir.path)
    }

    func testMeasureTargetTimeout() async throws {
        let testDir = tempDir.appendingPathComponent("timeout_test")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        let file = testDir.appendingPathComponent("a.bin")
        try Data(repeating: 1, count: 2048).write(to: file)

        do {
            _ = try await scanner.measureTarget(at: testDir, timeoutInterval: 0)
            XCTFail("Expected timeout error")
        } catch let error as ScannerServiceError {
            switch error {
            case .measurementTimedOut:
                XCTAssertTrue(true)
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testBuildDryRunPreview() async throws {
        let testDir = tempDir.appendingPathComponent("preview_test")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        let file1 = testDir.appendingPathComponent("first.txt")
        let file2 = testDir.appendingPathComponent("second.txt")
        try Data(repeating: 0, count: 1024).write(to: file1)
        try Data(repeating: 0, count: 512).write(to: file2)

        let preview = try await scanner.buildDryRunPreview(for: testDir, limit: 10)
        XCTAssertEqual(preview.totalItems, 2)
        XCTAssertEqual(preview.items.count, 2)
        XCTAssertGreaterThanOrEqual(preview.estimatedTotalBytes, 1536)
    }

    func testDiscoverLargeFiles() async throws {
        let dmgFile = tempDir.appendingPathComponent("installer.dmg")
        try Data(repeating: 2, count: 4096).write(to: dmgFile)

        let hits = try await scanner.discoverLargeFiles(
            roots: [tempDir],
            limit: 5,
            minimumSizeBytes: 1024
        )

        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(
            hits.first.map { URL(fileURLWithPath: $0.path).resolvingSymlinksInPath().path },
            dmgFile.resolvingSymlinksInPath().path
        )
        XCTAssertEqual(hits.first?.reason, "Installer image")
    }
}
