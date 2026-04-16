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
    var largeFileHits: [LargeFileHit] = []

    var isScanning = false
    var scanPhase: ScanPhase = .idle
    var lastError: String?
    var scanWarnings: [String] = []

    // Progress feedback
    var currentScanningPath: String?
    var scanProgressCompleted: Int = 0
    var scanProgressTotal: Int = 0

    // Exclusion
    let exclusionStore = ExclusionStore()
    var skippedExcludedCount: Int = 0

    // Metrics
    var timedOutTargetCount: Int = 0
    var lastScanDate: Date?
    var cacheSnapshotDate: Date?
    var isUsingCachedSnapshot = false

    // Dry-run previews
    private(set) var dryRunPreviews: [String: DryRunPreview] = [:]
    private var previewLoadingPaths: Set<String> = []

    var totalReclaimableBytes: Int64 {
        let scanBytes = scanTargets.reduce(0) { $0 + $1.allocatedSizeInBytes }
        let scanPaths = Set(scanTargets.map { $0.url.path })
        let uniqueLargeBytes = largeFileHits
            .filter { !scanPaths.contains($0.path) }
            .reduce(Int64(0)) { $0 + $1.allocatedSizeInBytes }
        return scanBytes + uniqueLargeBytes
    }

    var healthScore: Int {
        let freeRatio = diskFreeRatio
        let reclaimGB = Double(totalReclaimableBytes) / 1_073_741_824

        var score = 100
        score -= Int((1 - freeRatio) * 45)                    // Disk pressure
        score -= min(30, Int(reclaimGB * 4))                  // Reclaim opportunity implies poorer state
        score -= min(12, timedOutTargetCount * 2)             // Lower confidence if many timeouts

        return max(0, min(100, score))
    }

    var healthLabel: String {
        switch healthScore {
        case 80...: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Needs Attention"
        default: return "Critical"
        }
    }

    var isInitialLoading = false
    var permissionWarning: String?
    var toolAvailability: [String: Bool] = [:]
    var presetById: [String: Preset] = [:]
    var fullHomeProjectScanEnabled = false {
        didSet {
            guard fullHomeProjectScanEnabled != oldValue else { return }
            saveScanPreferences()
            applyScannerPreferences()
        }
    }

    /// Precomputed groups for Local Projects to keep view rendering fast with large datasets.
    private(set) var projectBreakdown: [ProjectBreakdownGroup] = []
    private(set) var projectBreakdownRevision = 0

    private let loader = PresetLoader()
    private let scanner = ScannerService()
    private let cacheStore = ScanCacheStore()
    private let fullHomeProjectScanDefaultsKey = "devreclaim.settings.fullHomeProjectScanEnabled"

    private let targetMeasurementBaseTimeout: TimeInterval = 1.5
    private let targetMeasurementMaxTimeout: TimeInterval = 8.0
    private let heavyTargetNames: Set<String> = ["node_modules", ".gradle", "DerivedData", "build", "target"]
    private let maxMeasuredTargetsPerPreset = 350
    private let realtimeScanIntervalSeconds: TimeInterval = 20 * 60
    private let fullHomeScanBackgroundIntervalSeconds: TimeInterval = 45 * 60
    private let fastCacheRefreshIntervalSeconds: TimeInterval = 3 * 60
    private let largeFileThresholdBytes: Int64 = 500 * 1_024 * 1_024

    private var realtimeScanTask: Task<Void, Never>?
    private var fastCacheRefreshTask: Task<Void, Never>?
    private var hasStartedRealtimeScanner = false
    private var hasStartedFastCacheRefresher = false
    private var pendingFastCacheRefresh = false

    init() {
        loadScanPreferences()
        applyScannerPreferences()
    }

    deinit {
        realtimeScanTask?.cancel()
        fastCacheRefreshTask?.cancel()
    }

    func loadPresets() {
        isInitialLoading = true
        do {
            presets = try loader.loadEmbeddedPresets()
            presetById = Dictionary(uniqueKeysWithValues: presets.map { ($0.id, $0) })
            restoreCachedSnapshot()
        } catch {
            lastError = "Failed to load presets: \(error.localizedDescription)"
        }
        isInitialLoading = false
        checkFullDiskAccess()

        Task {
            await checkTools()
            await startRealtimeAnalysisIfNeeded()
            await startFastCacheRefreshIfNeeded()
            await scanAll()
        }
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
        beginScan(resetWarnings: true)
        isScanning = true

        await performScan(preset: preset)

        currentScanningPath = nil
        scanPhase = .completed
        isScanning = false
        lastScanDate = Date()
        isUsingCachedSnapshot = false
        await rebuildProjectBreakdown()
        persistSnapshot()
        await drainQueuedFastCacheRefreshIfNeeded()
    }

    @MainActor
    func scanAll() async {
        guard !isScanning else { return }

        beginScan(resetWarnings: true)
        isScanning = true

        let projectPresets = presets.filter { $0.category == "project_artifact" }
        let nonProjectPresets = presets.filter { $0.category != "project_artifact" }

        for preset in nonProjectPresets {
            await performScan(preset: preset)
        }

        if !projectPresets.isEmpty {
            await performProjectArtifactBatchScan(presets: projectPresets)
        }

        await scanLargeFiles()

        currentScanningPath = nil
        scanPhase = .completed
        isScanning = false
        lastScanDate = Date()
        isUsingCachedSnapshot = false
        await rebuildProjectBreakdown()
        persistSnapshot()
        await drainQueuedFastCacheRefreshIfNeeded()
    }

    @MainActor
    private func performScan(preset: Preset) async {
        scanPhase = .discovery
        currentScanningPath = nil

        let previousByPath = Dictionary(uniqueKeysWithValues:
            scanTargets
                .filter { $0.matchingPresetId == preset.id }
                .map { ($0.url.path, $0) }
        )

        // Remove stale entries for this preset, then re-add discovered targets.
        scanTargets.removeAll { $0.matchingPresetId == preset.id }

        do {
            let rawTargets = try await scanner.discoverTargets(for: preset)
            let excluded = rawTargets.filter { exclusionStore.isExcluded($0.url) }
            let targets = rawTargets.filter { !exclusionStore.isExcluded($0.url) }
            let limitedTargets = limitTargetsForMeasurement(
                targets,
                previousByPath: previousByPath,
                presetName: preset.name
            )
            skippedExcludedCount += excluded.count

            scanPhase = .measuring
            scanProgressCompleted = 0
            scanProgressTotal = limitedTargets.count

            for index in limitedTargets.indices {
                var target = limitedTargets[index]
                currentScanningPath = target.url.path
                let previousTarget = previousByPath[target.url.path]
                let timeoutInterval = measurementTimeoutInterval(
                    for: target,
                    preset: preset,
                    previousTarget: previousTarget
                )

                do {
                    let measured = try await scanner.measureTarget(
                        at: target.url,
                        timeoutInterval: timeoutInterval
                    )
                    target.allocatedSizeInBytes = measured.allocatedBytes
                    target.lastAccessDate = measured.lastAccessDate
                    target.lastMeasuredAt = Date()
                    target.status = .ready
                    target.isSizeEstimate = false
                } catch ScannerServiceError.measurementTimedOut {
                    timedOutTargetCount += 1
                    target.status = .timedOut
                    target.isSizeEstimate = true
                    target.lastMeasuredAt = Date()

                    if let previous = previousByPath[target.url.path] {
                        target.allocatedSizeInBytes = previous.allocatedSizeInBytes
                        target.lastAccessDate = previous.lastAccessDate
                    }

                    let warning = "Timeout (\(String(format: "%.1f", timeoutInterval))s) while measuring \(target.url.lastPathComponent). Using last known size if available."
                    if !scanWarnings.contains(warning) {
                        scanWarnings.append(warning)
                    }
                } catch {
                    target.status = .failed
                    target.isSizeEstimate = true
                    target.lastMeasuredAt = Date()

                    if let previous = previousByPath[target.url.path] {
                        target.allocatedSizeInBytes = previous.allocatedSizeInBytes
                        target.lastAccessDate = previous.lastAccessDate
                    }

                    let warning = "Failed to measure \(target.url.lastPathComponent): \(error.localizedDescription)"
                    if !scanWarnings.contains(warning) {
                        scanWarnings.append(warning)
                    }
                }

                upsert(target)
                scanProgressCompleted += 1
            }
        } catch {
            let warning = "Scan failed for \(preset.name): \(error.localizedDescription)"
            if !scanWarnings.contains(warning) {
                scanWarnings.append(warning)
            }
            lastError = warning
            scanPhase = .idle
        }
    }

    @MainActor
    private func performProjectArtifactBatchScan(presets: [Preset]) async {
        guard !presets.isEmpty else { return }

        scanPhase = .discovery
        currentScanningPath = "Project artifacts"

        let presetIds = Set(presets.map { $0.id })
        let previousByPresetId: [String: [String: ScanTarget]] = Dictionary(
            uniqueKeysWithValues: presets.map { preset in
                let previousByPath = Dictionary(uniqueKeysWithValues:
                    scanTargets
                        .filter { $0.matchingPresetId == preset.id }
                        .map { ($0.url.path, $0) }
                )
                return (preset.id, previousByPath)
            }
        )

        // Remove stale project-artifact entries once, then refill from batched discovery.
        scanTargets.removeAll { target in
            guard let presetId = target.matchingPresetId else { return false }
            return presetIds.contains(presetId)
        }

        do {
            let rawTargetsByPreset = try await scanner.discoverProjectTargets(for: presets)
            var filteredByPreset: [(preset: Preset, targets: [ScanTarget])] = []
            var totalTargetsToMeasure = 0

            for preset in presets {
                let rawTargets = rawTargetsByPreset[preset.id] ?? []
                let excluded = rawTargets.filter { exclusionStore.isExcluded($0.url) }
                let visibleTargets = rawTargets.filter { !exclusionStore.isExcluded($0.url) }
                let limitedTargets = limitTargetsForMeasurement(
                    visibleTargets,
                    previousByPath: previousByPresetId[preset.id] ?? [:],
                    presetName: preset.name
                )
                skippedExcludedCount += excluded.count
                totalTargetsToMeasure += limitedTargets.count
                filteredByPreset.append((preset: preset, targets: limitedTargets))
            }

            scanPhase = .measuring
            scanProgressCompleted = 0
            scanProgressTotal = totalTargetsToMeasure

            for entry in filteredByPreset {
                let preset = entry.preset
                let targets = entry.targets

                for index in targets.indices {
                    var target = targets[index]
                    currentScanningPath = target.url.path
                    let previousTarget = previousByPresetId[preset.id]?[target.url.path]
                    let timeoutInterval = measurementTimeoutInterval(
                        for: target,
                        preset: preset,
                        previousTarget: previousTarget
                    )

                    do {
                        let measured = try await scanner.measureTarget(
                            at: target.url,
                            timeoutInterval: timeoutInterval
                        )
                        target.allocatedSizeInBytes = measured.allocatedBytes
                        target.lastAccessDate = measured.lastAccessDate
                        target.lastMeasuredAt = Date()
                        target.status = .ready
                        target.isSizeEstimate = false
                    } catch ScannerServiceError.measurementTimedOut {
                        timedOutTargetCount += 1
                        target.status = .timedOut
                        target.isSizeEstimate = true
                        target.lastMeasuredAt = Date()

                        if let previous = previousByPresetId[preset.id]?[target.url.path] {
                            target.allocatedSizeInBytes = previous.allocatedSizeInBytes
                            target.lastAccessDate = previous.lastAccessDate
                        }

                        let warning = "Timeout (\(String(format: "%.1f", timeoutInterval))s) while measuring \(target.url.lastPathComponent). Using last known size if available."
                        if !scanWarnings.contains(warning) {
                            scanWarnings.append(warning)
                        }
                    } catch {
                        target.status = .failed
                        target.isSizeEstimate = true
                        target.lastMeasuredAt = Date()

                        if let previous = previousByPresetId[preset.id]?[target.url.path] {
                            target.allocatedSizeInBytes = previous.allocatedSizeInBytes
                            target.lastAccessDate = previous.lastAccessDate
                        }

                        let warning = "Failed to measure \(target.url.lastPathComponent): \(error.localizedDescription)"
                        if !scanWarnings.contains(warning) {
                            scanWarnings.append(warning)
                        }
                    }

                    upsert(target)
                    scanProgressCompleted += 1
                }
            }
        } catch {
            let warning = "Project artifact scan failed: \(error.localizedDescription)"
            if !scanWarnings.contains(warning) {
                scanWarnings.append(warning)
            }
            lastError = warning
            scanPhase = .idle
        }
    }

    @MainActor
    private func scanLargeFiles() async {
        currentScanningPath = "Large file hunter"

        let home = FileManager.default.homeDirectoryForCurrentUser
        let roots = [
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Documents")
        ]

        do {
            largeFileHits = try await scanner.discoverLargeFiles(
                roots: roots,
                limit: 20,
                minimumSizeBytes: largeFileThresholdBytes
            )
        } catch {
            let warning = "Large file scan failed: \(error.localizedDescription)"
            if !scanWarnings.contains(warning) {
                scanWarnings.append(warning)
            }
        }
    }

    // MARK: - Dry Run Preview

    func dryRunPreview(for target: ScanTarget) -> DryRunPreview? {
        dryRunPreviews[target.url.path]
    }

    func isLoadingDryRunPreview(for target: ScanTarget) -> Bool {
        previewLoadingPaths.contains(target.url.path)
    }

    @MainActor
    func loadDryRunPreview(for target: ScanTarget, forceRefresh: Bool = false) async {
        let key = target.url.path

        if dryRunPreviews[key] != nil && !forceRefresh {
            return
        }
        if previewLoadingPaths.contains(key) {
            return
        }

        previewLoadingPaths.insert(key)
        defer { previewLoadingPaths.remove(key) }

        do {
            let preview = try await scanner.buildDryRunPreview(for: target.url, limit: 80)
            dryRunPreviews[key] = preview
        } catch {
            let warning = "Dry-run preview failed for \(target.url.lastPathComponent): \(error.localizedDescription)"
            if !scanWarnings.contains(warning) {
                scanWarnings.append(warning)
            }
        }
    }

    // MARK: - Private Helpers

    @MainActor
    private func startRealtimeAnalysisIfNeeded() {
        guard !hasStartedRealtimeScanner else { return }
        hasStartedRealtimeScanner = true

        realtimeScanTask = Task { [weak self] in
            while !Task.isCancelled {
                let intervalSeconds: TimeInterval
                if self?.fullHomeProjectScanEnabled == true {
                    intervalSeconds = self?.fullHomeScanBackgroundIntervalSeconds ?? 2_700
                } else {
                    intervalSeconds = self?.realtimeScanIntervalSeconds ?? 1_200
                }
                let ns = UInt64(intervalSeconds * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
                guard let self else { return }
                if self.fullHomeProjectScanEnabled {
                    await self.refreshFastCaches()
                } else {
                    await self.scanAll()
                }
            }
        }
    }

    @MainActor
    private func startFastCacheRefreshIfNeeded() {
        guard !hasStartedFastCacheRefresher else { return }
        hasStartedFastCacheRefresher = true

        fastCacheRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                let ns = UInt64((self?.fastCacheRefreshIntervalSeconds ?? 180) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
                guard let self else { return }
                await self.refreshFastCaches()
            }
        }
    }

    @MainActor
    func refreshFastCaches() async {
        guard !isScanning else {
            pendingFastCacheRefresh = true
            return
        }
        pendingFastCacheRefresh = false

        let fastPresets = presets.filter { $0.category == "global_cache" || $0.category == "system_cache" }
        guard !fastPresets.isEmpty else { return }

        beginScan(resetWarnings: false)
        isScanning = true

        for preset in fastPresets {
            await performScan(preset: preset)
        }

        currentScanningPath = nil
        scanPhase = .completed
        isScanning = false
        lastScanDate = Date()
        isUsingCachedSnapshot = false
        await rebuildProjectBreakdown()
        persistSnapshot()
        await drainQueuedFastCacheRefreshIfNeeded()
    }

    private func beginScan(resetWarnings: Bool) {
        scanPhase = .discovery
        lastError = nil
        skippedExcludedCount = 0
        currentScanningPath = nil
        scanProgressCompleted = 0
        scanProgressTotal = 0
        timedOutTargetCount = 0
        if resetWarnings {
            scanWarnings = []
        }
    }

    @MainActor
    private func drainQueuedFastCacheRefreshIfNeeded() async {
        guard pendingFastCacheRefresh, !isScanning else { return }
        pendingFastCacheRefresh = false
        await refreshFastCaches()
    }

    @MainActor
    private func rebuildProjectBreakdown() async {
        let groups = await buildProjectBreakdown(from: scanTargets)
        projectBreakdown = groups
        projectBreakdownRevision &+= 1
    }

    private func buildProjectBreakdown(from targets: [ScanTarget]) async -> [ProjectBreakdownGroup] {
        await Task.detached(priority: .utility) {
            let projectTargets = targets.filter { $0.projectURL != nil }
            let grouped = Dictionary(grouping: projectTargets) { $0.projectURL! }
            return grouped.map { (projectURL, bucket) in
                let total = bucket.reduce(Int64(0)) { $0 + $1.allocatedSizeInBytes }
                return ProjectBreakdownGroup(
                    projectURL: projectURL,
                    name: projectURL.lastPathComponent,
                    targets: bucket,
                    totalBytes: total
                )
            }
            .sorted { $0.totalBytes > $1.totalBytes }
        }.value
    }

    private func loadScanPreferences() {
        fullHomeProjectScanEnabled = UserDefaults.standard.bool(
            forKey: fullHomeProjectScanDefaultsKey
        )
    }

    private func saveScanPreferences() {
        UserDefaults.standard.set(
            fullHomeProjectScanEnabled,
            forKey: fullHomeProjectScanDefaultsKey
        )
    }

    private func applyScannerPreferences() {
        scanner.includesHomeProjectRoot = fullHomeProjectScanEnabled
    }

    private func measurementTimeoutInterval(
        for target: ScanTarget,
        preset: Preset,
        previousTarget: ScanTarget?
    ) -> TimeInterval {
        var timeout = targetMeasurementBaseTimeout

        // Project artifacts are frequently deep directory trees.
        if preset.category == "project_artifact" {
            timeout += 1.0
        } else if preset.category == "system_cache" {
            timeout += 0.5
        }

        if heavyTargetNames.contains(target.url.lastPathComponent) {
            timeout += 1.0
        }

        let previousBytes = max(Int64(0), previousTarget?.allocatedSizeInBytes ?? 0)
        if previousBytes >= 5 * 1_073_741_824 {               // 5 GB
            timeout += 3.0
        } else if previousBytes >= 1_073_741_824 {            // 1 GB
            timeout += 1.5
        } else if previousBytes >= 250 * 1_024 * 1_024 {      // 250 MB
            timeout += 0.75
        }

        return min(targetMeasurementMaxTimeout, timeout)
    }

    private func limitTargetsForMeasurement(
        _ targets: [ScanTarget],
        previousByPath: [String: ScanTarget],
        presetName: String
    ) -> [ScanTarget] {
        guard targets.count > maxMeasuredTargetsPerPreset else { return targets }

        // Keep likely high-impact targets first using previous known sizes when available.
        let prioritized = targets.sorted { lhs, rhs in
            let lhsSize = previousByPath[lhs.url.path]?.allocatedSizeInBytes ?? 0
            let rhsSize = previousByPath[rhs.url.path]?.allocatedSizeInBytes ?? 0
            if lhsSize != rhsSize {
                return lhsSize > rhsSize
            }
            return lhs.url.path < rhs.url.path
        }

        let limited = Array(prioritized.prefix(maxMeasuredTargetsPerPreset))
        let skippedCount = targets.count - limited.count
        let warning = "\(presetName): showing top \(limited.count) targets (skipped \(skippedCount)) to keep scan responsive."
        if !scanWarnings.contains(warning) {
            scanWarnings.append(warning)
        }
        return limited
    }

    private func upsert(_ target: ScanTarget) {
        if let index = scanTargets.firstIndex(where: { $0.identityKey == target.identityKey }) {
            scanTargets[index] = target
        } else {
            scanTargets.append(target)
        }
    }

    @MainActor
    func removeTargetFromResults(_ target: ScanTarget) {
        let key = target.identityKey
        scanTargets.removeAll { $0.identityKey == key }
        dryRunPreviews.removeValue(forKey: target.url.path)

        Task { @MainActor in
            await rebuildProjectBreakdown()
            persistSnapshot()
        }
    }

    private var diskFreeRatio: Double {
        guard let values = try? URL(fileURLWithPath: NSHomeDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]),
              let free = values.volumeAvailableCapacityForImportantUsage,
              let total = values.volumeTotalCapacity,
              total > 0 else {
            return 0.5
        }
        return Double(free) / Double(total)
    }

    private func restoreCachedSnapshot() {
        guard let snapshot = cacheStore.load() else { return }

        let validPresetIds = Set(presets.map { $0.id })
        scanTargets = snapshot.scanTargets.filter {
            guard let presetId = $0.matchingPresetId else { return true }
            return validPresetIds.contains(presetId)
        }
        largeFileHits = snapshot.largeFileHits
        skippedExcludedCount = snapshot.skippedExcludedCount
        timedOutTargetCount = snapshot.timedOutTargetCount
        scanWarnings = snapshot.warnings
        lastScanDate = snapshot.savedAt
        cacheSnapshotDate = snapshot.savedAt
        isUsingCachedSnapshot = !scanTargets.isEmpty || !largeFileHits.isEmpty
        projectBreakdown = buildProjectBreakdownSync(from: scanTargets)
        projectBreakdownRevision &+= 1

        if isUsingCachedSnapshot {
            scanPhase = .completed
        }
    }

    private func persistSnapshot() {
        let snapshot = ScanCacheSnapshot(
            savedAt: Date(),
            scanTargets: scanTargets,
            largeFileHits: largeFileHits,
            skippedExcludedCount: skippedExcludedCount,
            timedOutTargetCount: timedOutTargetCount,
            warnings: scanWarnings
        )
        cacheStore.save(snapshot)
        cacheSnapshotDate = snapshot.savedAt
    }

    private func buildProjectBreakdownSync(from targets: [ScanTarget]) -> [ProjectBreakdownGroup] {
        let projectTargets = targets.filter { $0.projectURL != nil }
        let grouped = Dictionary(grouping: projectTargets) { $0.projectURL! }
        return grouped.map { (projectURL, bucket) in
            let total = bucket.reduce(Int64(0)) { $0 + $1.allocatedSizeInBytes }
            return ProjectBreakdownGroup(
                projectURL: projectURL,
                name: projectURL.lastPathComponent,
                targets: bucket,
                totalBytes: total
            )
        }
        .sorted { $0.totalBytes > $1.totalBytes }
    }
}
