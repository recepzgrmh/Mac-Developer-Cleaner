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
    
    // Metrics
    var totalReclaimableBytes: Int64 {
        scanTargets.reduce(0) { $0 + $1.allocatedSizeInBytes }
    }
    
    var isInitialLoading = false
    var permissionWarning: String?
    var toolAvailability: [String: Bool] = [:]
    
    private let loader = PresetLoader()
    private let scanner = ScannerService()
    
    func loadPresets() {
        isInitialLoading = true
        do {
            self.presets = try loader.loadEmbeddedPresets()
            checkTools()
        } catch {
            self.lastError = "Failed to load presets: \(error.localizedDescription)"
        }
        isInitialLoading = false
    }
    
    private func checkTools() {
        // Simple mock for MVP: check if some tools might be missing
        for preset in presets {
            if let tool = preset.requiresToolInstalled {
                // In a real app, we'd check if `which tool` returns something
                toolAvailability[tool] = true // Assume true for now
            }
        }
    }
    
    @MainActor
    func scan(preset: Preset) async {
        isScanning = true
        scanPhase = .discovery
        lastError = nil
        
        do {
            let targets = try await scanner.discoverTargets(for: preset)
            
            scanPhase = .measuring
            // Update or add targets
            for var target in targets {
                let size = try await scanner.calculateVolume(for: target.url)
                target.allocatedSizeInBytes = size
                target.status = .ready
                
                if let index = scanTargets.firstIndex(where: { $0.url == target.url }) {
                    scanTargets[index] = target
                } else {
                    scanTargets.append(target)
                }
            }
            scanPhase = .completed
        } catch {
            lastError = "Scan failed: \(error.localizedDescription)"
            scanPhase = .idle
        }
        
        isScanning = false
    }
    
    @MainActor
    func scanAll() async {
        isScanning = true
        for preset in presets {
            await scan(preset: preset)
        }
        isScanning = false
    }
}
