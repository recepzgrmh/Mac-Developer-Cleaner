import SwiftUI

struct PresetRowView: View {
    let preset: Preset
    let target: ScanTarget?
    let isScanning: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: categoryIcon)
                    .foregroundColor(.accentColor)
                    .font(.system(size: 14, weight: .semibold))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.name)
                    .font(.headline)
                
                Text(preset.explanation)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                if isScanning && target == nil {
                    ProgressView()
                        .controlSize(.small)
                } else if let target = target {
                    Text(ByteCountFormatter.string(fromByteCount: target.allocatedSizeInBytes, countStyle: .file))
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(.primary)
                    
                    RiskBadge(level: preset.riskLevel)
                } else {
                    Text("Not scanned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var categoryIcon: String {
        switch preset.category {
        case "global_cache": return "archivebox"
        case "project_artifact": return "hammer"
        default: return "folder"
        }
    }
}
