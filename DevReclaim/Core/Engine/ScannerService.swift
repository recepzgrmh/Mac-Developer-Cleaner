import Foundation

protocol ScannerServiceProtocol {
    /// Discovers targets for a given preset based on its category.
    func discoverTargets(for preset: Preset) async throws -> [ScanTarget]
    
    /// Discovers targets for a global cache preset.
    func discoverGlobalTargets(for preset: Preset) async throws -> [ScanTarget]
    
    /// Discovers targets within a project directory for a project artifact preset.
    func discoverProjectTargets(in projectURL: URL, for preset: Preset) async throws -> [ScanTarget]
    
    /// Calculates the disk volume occupied by a given URL using Apple's recommended allocation keys.
    func calculateVolume(for url: URL) async throws -> Int64
}

class ScannerService: ScannerServiceProtocol {
    
    private let fileManager = FileManager.default
    
    func discoverTargets(for preset: Preset) async throws -> [ScanTarget] {
        if preset.category == "global_cache" {
            return try await discoverGlobalTargets(for: preset)
        } else if preset.category == "project_artifact" {
            // Default project search path for MVP: ~/Developer
            let home = FileManager.default.homeDirectoryForCurrentUser
            let developerDir = home.appendingPathComponent("Developer")
            
            if fileManager.fileExists(atPath: developerDir.path) {
                return try await discoverProjectTargets(in: developerDir, for: preset)
            }
        }
        return []
    }
    
    func discoverGlobalTargets(for preset: Preset) async throws -> [ScanTarget] {
        guard preset.category == "global_cache" else { return [] }
        
        let nsPath = preset.pathResolver as NSString
        let resolvedPath = nsPath.expandingTildeInPath
        let url = URL(fileURLWithPath: resolvedPath)
        
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: resolvedPath, isDirectory: &isDir) {
            let target = ScanTarget(
                url: url,
                matchingPresetId: preset.id,
                status: .discovered
            )
            return [target]
        }
        
        return []
    }
    
    func discoverProjectTargets(in projectURL: URL, for preset: Preset) async throws -> [ScanTarget] {
        guard preset.category == "project_artifact" else { return [] }
        
        return await Task.detached(priority: .userInitiated) {
            var targets: [ScanTarget] = []
            
            // Search for the specific artifact (e.g., "build", "node_modules")
            let artifactName = preset.pathResolver
            
            let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .nameKey]
            guard let enumerator = self.fileManager.enumerator(
                at: projectURL,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsPackageDescendants]
            ) else {
                return []
            }
            
            while let fileURL = enumerator.nextObject() as? URL {
                // Rule: If we hit a .git directory, skip it entirely.
                if fileURL.lastPathComponent == ".git" {
                    enumerator.skipDescendants()
                    continue
                }
                
                guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                      let isDirectory = resourceValues.isDirectory else {
                    continue
                }
                
                if isDirectory && fileURL.lastPathComponent == artifactName {
                    // Match found — record the containing project directory for per-project breakdown.
                    let projectURL = fileURL.deletingLastPathComponent()
                    let target = ScanTarget(
                        url: fileURL,
                        matchingPresetId: preset.id,
                        projectURL: projectURL,
                        status: .discovered
                    )
                    targets.append(target)
                    
                    // Once we find a target (like node_modules or build), 
                    // we usually don't need to scan deeper inside it for the same artifact.
                    enumerator.skipDescendants()
                }
            }
            
            return targets
        }.value
    }
    
    func calculateVolume(for url: URL) async throws -> Int64 {
        return await Task.detached(priority: .userInitiated) {
            var totalVolume: Int64 = 0
            
            // Apple recommendation: totalFileAllocatedSizeKey for actual disk space.
            let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey]
            
            // Note: We don't skip .git here if it's INSIDE a target we are already measuring, 
            // but the scanner discovery should have avoided making a .git-boundary-parent a target.
            guard let enumerator = self.fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            ) else {
                return 0
            }
            
            while let fileURL = enumerator.nextObject() as? URL {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys)),
                      let isRegularFile = resourceValues.isRegularFile,
                      isRegularFile,
                      let fileSize = resourceValues.totalFileAllocatedSize else {
                    continue
                }
                
                totalVolume += Int64(fileSize)
            }
            
            return totalVolume
        }.value
    }
}
