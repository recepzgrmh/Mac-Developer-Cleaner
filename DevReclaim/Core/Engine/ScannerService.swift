import Foundation

enum ScannerServiceError: LocalizedError {
    case measurementTimedOut(path: String, timeoutSeconds: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .measurementTimedOut(let path, let timeoutSeconds):
            let formatted = String(format: "%.1f", timeoutSeconds)
            return "Measurement timed out after \(formatted)s: \(path)"
        }
    }
}

struct TargetMeasurement {
    let allocatedBytes: Int64
    let lastAccessDate: Date?
}

protocol ScannerServiceProtocol {
    /// Discovers targets for a given preset based on its category.
    func discoverTargets(for preset: Preset) async throws -> [ScanTarget]

    /// Discovers targets for a global cache preset.
    func discoverGlobalTargets(for preset: Preset) async throws -> [ScanTarget]

    /// Discovers targets for a system cache preset.
    func discoverSystemTargets(for preset: Preset) async throws -> [ScanTarget]

    /// Discovers targets within a project directory for a project artifact preset.
    func discoverProjectTargets(in projectURL: URL, for preset: Preset) async throws -> [ScanTarget]

    /// Calculates the disk volume occupied by a given URL.
    func calculateVolume(for url: URL) async throws -> Int64

    /// Measures size and last-access time for a given target.
    func measureTarget(at url: URL, timeoutInterval: TimeInterval?) async throws -> TargetMeasurement

    /// Builds a dry-run preview to show what would be deleted.
    func buildDryRunPreview(for url: URL, limit: Int) async throws -> DryRunPreview

    /// Finds likely reclaimable large files.
    func discoverLargeFiles(roots: [URL], limit: Int, minimumSizeBytes: Int64) async throws -> [LargeFileHit]
}

class ScannerService: ScannerServiceProtocol {

    private let fileManager = FileManager.default
    /// When enabled, project artifact discovery also scans the entire home directory (`~`).
    var includesHomeProjectRoot = false

    func discoverTargets(for preset: Preset) async throws -> [ScanTarget] {
        switch preset.category {
        case "global_cache":
            return try await discoverGlobalTargets(for: preset)
        case "system_cache":
            return try await discoverSystemTargets(for: preset)
        case "project_artifact":
            return try await discoverDefaultProjectTargets(for: preset)
        default:
            return []
        }
    }

    func discoverGlobalTargets(for preset: Preset) async throws -> [ScanTarget] {
        guard preset.category == "global_cache" else { return [] }
        return try await discoverFileSystemTargets(for: preset)
    }

    func discoverSystemTargets(for preset: Preset) async throws -> [ScanTarget] {
        guard preset.category == "system_cache" else { return [] }
        return try await discoverFileSystemTargets(for: preset)
    }

    func discoverProjectTargets(in projectURL: URL, for preset: Preset) async throws -> [ScanTarget] {
        guard preset.category == "project_artifact" else { return [] }

        let foundByPreset = try await discoverProjectTargets(
            in: projectURL,
            artifactNames: [preset.pathResolver],
            presetsByArtifactName: [preset.pathResolver: [preset]]
        )
        return foundByPreset[preset.id] ?? []
    }

    /// Discovers project artifact targets for multiple presets in a single filesystem pass per root.
    func discoverProjectTargets(for presets: [Preset]) async throws -> [String: [ScanTarget]] {
        let projectPresets = presets.filter { $0.category == "project_artifact" }
        guard !projectPresets.isEmpty else { return [:] }

        let presetsByArtifactName = Dictionary(grouping: projectPresets, by: { $0.pathResolver })
        let artifactNames = Set(presetsByArtifactName.keys)
        let candidateRoots = discoverProjectRoots()

        var targetsByPresetId: [String: [ScanTarget]] = [:]
        for preset in projectPresets {
            targetsByPresetId[preset.id] = []
        }

        for root in candidateRoots {
            let found = try await discoverProjectTargets(
                in: root,
                artifactNames: artifactNames,
                presetsByArtifactName: presetsByArtifactName
            )
            for (presetId, targets) in found {
                targetsByPresetId[presetId, default: []].append(contentsOf: targets)
            }
        }

        // Unique by path for each preset to avoid duplicates when roots overlap.
        for (presetId, targets) in targetsByPresetId {
            let unique = Dictionary(grouping: targets, by: { $0.url.path }).compactMap { _, values in
                values.first
            }
            targetsByPresetId[presetId] = unique
        }

        return targetsByPresetId
    }

    func calculateVolume(for url: URL) async throws -> Int64 {
        try await measureTarget(at: url, timeoutInterval: nil).allocatedBytes
    }

    func measureTarget(at url: URL, timeoutInterval: TimeInterval? = nil) async throws -> TargetMeasurement {
        if let timeoutInterval, timeoutInterval <= 0 {
            throw ScannerServiceError.measurementTimedOut(path: url.path, timeoutSeconds: timeoutInterval)
        }

        return try await withThrowingTaskGroup(of: TargetMeasurement.self) { group in
            group.addTask {
                try await self.performMeasurement(for: url)
            }

            if let timeoutInterval {
                group.addTask {
                    let nanoseconds = UInt64(timeoutInterval * 1_000_000_000)
                    try await Task.sleep(nanoseconds: nanoseconds)
                    throw ScannerServiceError.measurementTimedOut(path: url.path, timeoutSeconds: timeoutInterval)
                }
            }

            guard let first = try await group.next() else {
                throw CancellationError()
            }
            group.cancelAll()
            return first
        }
    }

    func buildDryRunPreview(for url: URL, limit: Int = 80) async throws -> DryRunPreview {
        return await Task.detached(priority: .userInitiated) {
            let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .totalFileAllocatedSizeKey]
            var items: [DryRunPreviewItem] = []
            var totalItems = 0
            var totalBytes: Int64 = 0
            let truncatedLimit = max(1, limit)

            guard self.fileManager.fileExists(atPath: url.path) else {
                return DryRunPreview(
                    targetPath: url.path,
                    generatedAt: Date(),
                    totalItems: 0,
                    estimatedTotalBytes: 0,
                    isTruncated: false,
                    items: []
                )
            }

            let rootValues = try? url.resourceValues(forKeys: Set(keys))
            if rootValues?.isRegularFile == true {
                let size = Int64(rootValues?.totalFileAllocatedSize ?? 0)
                let item = DryRunPreviewItem(path: url.lastPathComponent, allocatedSizeInBytes: size, isDirectory: false)
                return DryRunPreview(
                    targetPath: url.path,
                    generatedAt: Date(),
                    totalItems: 1,
                    estimatedTotalBytes: size,
                    isTruncated: false,
                    items: [item]
                )
            }

            guard let enumerator = self.fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            ) else {
                return DryRunPreview(
                    targetPath: url.path,
                    generatedAt: Date(),
                    totalItems: 0,
                    estimatedTotalBytes: 0,
                    isTruncated: false,
                    items: []
                )
            }

            let rootPrefix = url.path.hasSuffix("/") ? url.path : url.path + "/"

            while let childURL = enumerator.nextObject() as? URL {
                if Task.isCancelled { break }

                let values = try? childURL.resourceValues(forKeys: Set(keys))
                let isDirectory = values?.isDirectory ?? false
                let size = Int64(values?.totalFileAllocatedSize ?? 0)

                totalItems += 1
                if !isDirectory {
                    totalBytes += size
                }

                if items.count < truncatedLimit {
                    let relativePath: String
                    if childURL.path.hasPrefix(rootPrefix) {
                        relativePath = String(childURL.path.dropFirst(rootPrefix.count))
                    } else {
                        relativePath = childURL.lastPathComponent
                    }
                    items.append(
                        DryRunPreviewItem(
                            path: relativePath,
                            allocatedSizeInBytes: size,
                            isDirectory: isDirectory
                        )
                    )
                }
            }

            return DryRunPreview(
                targetPath: url.path,
                generatedAt: Date(),
                totalItems: totalItems,
                estimatedTotalBytes: totalBytes,
                isTruncated: totalItems > truncatedLimit,
                items: items
            )
        }.value
    }

    func discoverLargeFiles(
        roots: [URL],
        limit: Int = 15,
        minimumSizeBytes: Int64 = 500 * 1_024 * 1_024
    ) async throws -> [LargeFileHit] {
        return await Task.detached(priority: .utility) {
            let keys: [URLResourceKey] = [
                .isDirectoryKey,
                .isRegularFileKey,
                .totalFileAllocatedSizeKey,
                .contentAccessDateKey,
                .attributeModificationDateKey
            ]
            let installerExtensions: Set<String> = ["dmg", "pkg", "ipsw"]
            let partialExtensions: Set<String> = ["download", "crdownload", "part"]
            var hits: [LargeFileHit] = []

            let skipDirs: Set<String> = [".git", ".Trash", "Library", "node_modules", ".gradle", ".cache"]

            for root in roots where self.fileManager.fileExists(atPath: root.path) {
                guard let enumerator = self.fileManager.enumerator(
                    at: root,
                    includingPropertiesForKeys: keys,
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else {
                    continue
                }

                while let fileURL = enumerator.nextObject() as? URL {
                    if Task.isCancelled { return [] }

                    guard let values = try? fileURL.resourceValues(forKeys: Set(keys)) else {
                        continue
                    }

                    let isDirectory = values.isDirectory ?? false
                    if isDirectory {
                        if skipDirs.contains(fileURL.lastPathComponent) {
                            enumerator.skipDescendants()
                        }
                        continue
                    }

                    guard values.isRegularFile == true else { continue }
                    let size = Int64(values.totalFileAllocatedSize ?? 0)
                    let ext = fileURL.pathExtension.lowercased()
                    let isInstaller = installerExtensions.contains(ext)
                    let isPartial = partialExtensions.contains(ext)
                    let isLarge = size >= minimumSizeBytes

                    guard isInstaller || isPartial || isLarge else { continue }

                    let reason: String
                    if isPartial {
                        reason = "Partial download"
                    } else if isInstaller {
                        reason = "Installer image"
                    } else {
                        reason = "Large file"
                    }

                    let accessDate = values.contentAccessDate ?? values.attributeModificationDate
                    hits.append(
                        LargeFileHit(
                            path: fileURL.path,
                            allocatedSizeInBytes: size,
                            lastAccessDate: accessDate,
                            reason: reason
                        )
                    )
                }
            }

            let deduped = Dictionary(grouping: hits, by: { $0.path }).compactMap { _, values in
                values.max(by: { $0.allocatedSizeInBytes < $1.allocatedSizeInBytes })
            }

            return deduped
                .sorted { $0.allocatedSizeInBytes > $1.allocatedSizeInBytes }
                .prefix(max(1, limit))
                .map { $0 }
        }.value
    }

    // MARK: - Private Helpers

    private func discoverDefaultProjectTargets(for preset: Preset) async throws -> [ScanTarget] {
        let targetsByPreset = try await discoverProjectTargets(for: [preset])
        return targetsByPreset[preset.id] ?? []
    }

    private func discoverProjectRoots() -> [URL] {
        let home = fileManager.homeDirectoryForCurrentUser
        var candidates: [URL] = [
            home.appendingPathComponent("Developer"),
            home.appendingPathComponent("Projects"),
            home.appendingPathComponent("Work"),
            home.appendingPathComponent("Code"),
            home.appendingPathComponent("Workspace"),
            home.appendingPathComponent("Repos"),
            home.appendingPathComponent("Repositories"),
            home.appendingPathComponent("Development"),
            home.appendingPathComponent("Source"),
            home.appendingPathComponent("src"),
            home.appendingPathComponent("Documents/Projects"),
            home.appendingPathComponent("Documents/Code"),
            home.appendingPathComponent("Desktop/Projects")
        ]

        if includesHomeProjectRoot {
            candidates.append(home)
        }

        if let customRoots = ProcessInfo.processInfo.environment["DEVRECLAIM_PROJECT_ROOTS"],
           !customRoots.isEmpty {
            let extras = customRoots
                .split(separator: ":")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
            candidates.append(contentsOf: extras)
        }

        var seenPaths = Set<String>()
        var roots: [URL] = []

        for candidate in candidates {
            let normalized = candidate.standardizedFileURL
            guard seenPaths.insert(normalized.path).inserted else { continue }

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: normalized.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }
            roots.append(normalized)
        }

        return roots
    }

    private func discoverProjectTargets(
        in rootURL: URL,
        artifactNames: Set<String>,
        presetsByArtifactName: [String: [Preset]]
    ) async throws -> [String: [ScanTarget]] {
        guard !artifactNames.isEmpty else { return [:] }

        return await Task.detached(priority: .userInitiated) {
            var targetsByPresetId: [String: [ScanTarget]] = [:]
            let resourceKeys: [URLResourceKey] = [.isDirectoryKey]

            guard let enumerator = self.fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsPackageDescendants]
            ) else {
                return [:]
            }

            let homePath = self.fileManager.homeDirectoryForCurrentUser.standardizedFileURL.path
            let isHomeWideRoot = self.includesHomeProjectRoot && rootURL.standardizedFileURL.path == homePath
            let homeWidePrunedDirectories: Set<String> = isHomeWideRoot
                ? ["Library", "Applications", ".Trash", ".Spotlight-V100", ".fseventsd"]
                : []

            while let fileURL = enumerator.nextObject() as? URL {
                if Task.isCancelled { return [:] }

                guard let isDirectory = (try? fileURL.resourceValues(forKeys: Set(resourceKeys)))?.isDirectory,
                      isDirectory else {
                    continue
                }

                let name = fileURL.lastPathComponent
                if name == ".git" || homeWidePrunedDirectories.contains(name) {
                    enumerator.skipDescendants()
                    continue
                }

                guard artifactNames.contains(name),
                      let matchingPresets = presetsByArtifactName[name] else {
                    continue
                }

                let containingProjectURL = fileURL.deletingLastPathComponent()
                for preset in matchingPresets {
                    let target = ScanTarget(
                        url: fileURL,
                        matchingPresetId: preset.id,
                        projectURL: containingProjectURL,
                        status: .discovered
                    )
                    targetsByPresetId[preset.id, default: []].append(target)
                }
                enumerator.skipDescendants()
            }

            return targetsByPresetId
        }.value
    }

    private func discoverFileSystemTargets(for preset: Preset) async throws -> [ScanTarget] {
        switch preset.detectionMethod {
        case .directory_exists:
            let resolvedPath = (preset.pathResolver as NSString).expandingTildeInPath
            let url = URL(fileURLWithPath: resolvedPath)

            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: resolvedPath, isDirectory: &isDir) {
                let target = ScanTarget(url: url, matchingPresetId: preset.id, status: .discovered)
                return [target]
            }
            return []

        case .glob_match:
            return try await discoverGlobTargets(for: preset)
        }
    }

    private func discoverGlobTargets(for preset: Preset) async throws -> [ScanTarget] {
        let expanded = (preset.pathResolver as NSString).expandingTildeInPath
        let baseURL: URL
        let pattern: String

        if expanded.contains("*") {
            let nsExpanded = expanded as NSString
            baseURL = URL(fileURLWithPath: nsExpanded.deletingLastPathComponent)
            pattern = nsExpanded.lastPathComponent
        } else {
            baseURL = URL(fileURLWithPath: expanded)
            pattern = "*"
        }

        guard fileManager.fileExists(atPath: baseURL.path),
              let enumerator = fileManager.enumerator(
                at: baseURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }

        var targets: [ScanTarget] = []
        while let fileURL = enumerator.nextObject() as? URL {
            if Task.isCancelled { return [] }

            let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard !isDirectory else { continue }

            let fileName = fileURL.lastPathComponent
            if matchesGlob(fileName, pattern: pattern) {
                targets.append(ScanTarget(url: fileURL, matchingPresetId: preset.id, status: .discovered))
            }
        }

        return targets
    }

    private func matchesGlob(_ fileName: String, pattern: String) -> Bool {
        if pattern == "*" { return true }
        if pattern.hasPrefix("*.") {
            return fileName.lowercased().hasSuffix(pattern.dropFirst().lowercased())
        }
        if pattern.hasPrefix("*") {
            let suffix = String(pattern.dropFirst()).lowercased()
            return fileName.lowercased().hasSuffix(suffix)
        }
        return fileName == pattern
    }

    private func performMeasurement(for url: URL) async throws -> TargetMeasurement {
        return try await Task.detached(priority: .userInitiated) {
            let keys: [URLResourceKey] = [
                .isRegularFileKey,
                .totalFileAllocatedSizeKey,
                .contentAccessDateKey,
                .attributeModificationDateKey
            ]

            // Fast path for single files.
            if let rootValues = try? url.resourceValues(forKeys: Set(keys)), rootValues.isRegularFile == true {
                let size = Int64(rootValues.totalFileAllocatedSize ?? 0)
                let accessDate = rootValues.contentAccessDate ?? rootValues.attributeModificationDate
                return TargetMeasurement(allocatedBytes: size, lastAccessDate: accessDate)
            }

            var totalVolume: Int64 = 0
            var latestAccessDate: Date?

            guard let enumerator = self.fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            ) else {
                return TargetMeasurement(allocatedBytes: 0, lastAccessDate: nil)
            }

            while let fileURL = enumerator.nextObject() as? URL {
                try Task.checkCancellation()

                guard let values = try? fileURL.resourceValues(forKeys: Set(keys)) else {
                    continue
                }

                if values.isRegularFile == true {
                    totalVolume += Int64(values.totalFileAllocatedSize ?? 0)
                }

                if let candidateDate = values.contentAccessDate ?? values.attributeModificationDate {
                    if let existing = latestAccessDate {
                        if candidateDate > existing {
                            latestAccessDate = candidateDate
                        }
                    } else {
                        latestAccessDate = candidateDate
                    }
                }
            }

            return TargetMeasurement(allocatedBytes: totalVolume, lastAccessDate: latestAccessDate)
        }.value
    }
}
