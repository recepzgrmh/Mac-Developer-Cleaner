import Foundation
import Observation

@Observable
class ScannerViewModel {
    var presets: [Preset] = []
    var scanTargets: [ScanTarget] = []
    var isScanning = false
    var lastError: String?
    
    private let loader = PresetLoader()
    private let scanner = ScannerService()
    
    func loadPresets() {
        do {
            self.presets = try loader.loadEmbeddedPresets()
        } catch {
            self.lastError = "Failed to load presets: \(error.localizedDescription)"
        }
    }
    
    @MainActor
    func scan(preset: Preset) async {
        isScanning = true
        lastError = nil
        
        do {
            let targets = try await scanner.discoverTargets(for: preset)
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
        } catch {
            lastError = "Scan failed: \(error.localizedDescription)"
        }
        
        isScanning = false
    }
}
