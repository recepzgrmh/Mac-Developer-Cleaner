import SwiftUI

struct PresetRowView: View {
    let preset: Preset
    let target: ScanTarget?
    let isScanning: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
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
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(preset.explanation)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                if isScanning && target == nil {
                    ProgressView()
                        .controlSize(.small)
                } else if let target {
                    Text(ByteCountFormatter.string(fromByteCount: target.allocatedSizeInBytes, countStyle: .file))
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(.primary)

                    if let access = target.relativeLastAccessDescription {
                        Text("Used \(access)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    if target.status == .timedOut {
                        Label("Estimated", systemImage: "clock.badge.exclamationmark")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .lineLimit(1)
                    }

                    RiskBadge(level: preset.riskLevel)
                } else {
                    Text("Not scanned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.vertical, 4)
    }

    private var categoryIcon: String {
        switch preset.category {
        case "global_cache": return "archivebox"
        case "project_artifact": return "hammer"
        case "system_cache": return "memorychip"
        default: return "folder"
        }
    }
}
