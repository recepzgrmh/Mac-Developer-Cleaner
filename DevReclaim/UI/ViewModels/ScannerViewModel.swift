import Foundation
import Observation

@Observable
class ScannerViewModel {
    enum ScanPhase: Equatable {
        case idle
        case discovery
        case measuring
        case completed
    }

    var presets: [Preset] = []
    var scanTargets: [ScanTarget] = []
    var isScanning = false
    var scanPhase: ScanPhase = .idle
    var lastError: String?

    // Progress feedback
    var currentScanningPath: String?
    var scanProgressCompleted: Int = 0
    var scanProgressTotal: Int = 0

    // Exclusion
    let exclusionStore = ExclusionStore()
    var skippedExcludedCount: Int = 0

    // Metrics
    var totalReclaimableBytes: Int64 {
        scanTargets.reduce(0) { $0 + $1.allocatedSizeInBytes }
    }

    var isInitialLoading = false
    var permissionWarning: String?
    var toolAvailability: [String: Bool] = [:]

    /// Groups project_artifact scan results by their containing project directory, sorted by size descending.
    var projectBreakdown: [(projectURL: URL, name: String, targets: [ScanTarget], totalBytes: Int64)] {
        let projectTargets = scanTargets.filter { $0.projectURL != nil }
        let grouped = Dictionary(grouping: projectTargets) { $0.projectURL! }
        return grouped.map { (projectURL, targets) in
            let total = targets.reduce(0) { $0 + $1.allocatedSizeInBytes }
            return (projectURL: projectURL, name: projectURL.lastPathComponent, targets: targets, totalBytes: total)
        }.sorted { $0.totalBytes > $1.totalBytes }
    }

    private let loader = PresetLoader()
    private let scanner = ScannerService()

    func loadPresets() {
        isInitialLoading = true
        do {
            self.presets = try loader.loadEmbeddedPresets()
        } catch {
            self.lastError = "Failed to load presets: \(error.localizedDescription)"
        }
        isInitialLoading = false
        checkFullDiskAccess()
        Task { await checkTools() }
    }

    // MARK: - Full Disk Access

    func checkFullDiskAccess() {
        let testPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Safari")
        if !FileManager.default.isReadableFile(atPath: testPath.path) {
            permissionWarning = "Full Disk Access not granted — some locations may be skipped. Enable it in System Settings → Privacy & Security → Full Disk Access."
        } else {
            permissionWarning = nil
        }
    }

    // MARK: - Tool Availability

    private func checkTools() async {
        for preset in presets {
            if let tool = preset.requiresToolInstalled {
                let available = await isToolInstalled(tool)
                await MainActor.run { toolAvailability[tool] = available }
            }
        }
    }

    private func isToolInstalled(_ tool: String) async -> Bool {
        await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            process.arguments = [tool]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            try? process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        }.value
    }

    // MARK: - Scanning

    @MainActor
    func scan(preset: Preset) async {
        guard !isScanning else { return }
        isScanning = true
        scanPhase = .discovery
        lastError = nil
        skippedExcludedCount = 0
        currentScanningPath = nil

        do {
            let rawTargets = try await scanner.discoverTargets(for: preset)

            // Filter out user-excluded paths.
            let excluded = rawTargets.filter { exclusionStore.isExcluded($0.url) }
            let targets = rawTargets.filter { !exclusionStore.isExcluded($0.url) }
            skippedExcludedCount += excluded.count

            scanPhase = .measuring
            scanProgressCompleted = 0
            scanProgressTotal = targets.count

            for var target in targets {
                currentScanningPath = target.url.path
                let size = try await scanner.calculateVolume(for: target.url)
                target.allocatedSizeInBytes = size
                target.status = .ready

                if let index = scanTargets.firstIndex(where: { $0.url == target.url }) {
                    scanTargets[index] = target
                } else {
                    scanTargets.append(target)
                }
                scanProgressCompleted += 1
            }

            currentScanningPath = nil
            scanPhase = .completed
        } catch {
            lastError = "Scan failed: \(error.localizedDescription)"
            scanPhase = .idle
        }

        isScanning = false
    }

    @MainActor
    func scanAll() async {
        guard !isScanning else { return }
        isScanning = true
        for preset in presets {
            await scan(preset: preset)
        }
        isScanning = false
    }
}
