import SwiftUI

struct OverviewDashboardView: View {
    let scannerVM: ScannerViewModel

    var body: some View {
        ScrollView(showsIndicators: true) {
            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Storage Overview")
                        .font(.largeTitle.bold())

                    HStack(spacing: 10) {
                        if let subtitle = scanSubtitle {
                            Label(subtitle, systemImage: scannerVM.isUsingCachedSnapshot ? "clock.arrow.circlepath" : "checkmark.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if scannerVM.timedOutTargetCount > 0 {
                            Label("\(scannerVM.timedOutTargetCount) timeout", systemImage: "clock.badge.exclamationmark")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 130, maximum: 200))],
                    spacing: 16
                ) {
                    StatCard(
                        title: "Disk Health",
                        value: "\(scannerVM.healthScore)/100",
                        subtitle: scannerVM.healthLabel,
                        icon: "heart.text.square.fill",
                        color: healthColor
                    )

                    StatCard(
                        title: "Reclaimable",
                        value: ByteCountFormatter.string(fromByteCount: scannerVM.totalReclaimableBytes, countStyle: .file),
                        subtitle: "Total opportunity",
                        icon: "leaf.fill",
                        color: .green
                    )

                    StatCard(
                        title: "Found Targets",
                        value: "\(scannerVM.scanTargets.count)",
                        subtitle: "Caches and artifacts",
                        icon: "target",
                        color: .blue
                    )

                    StatCard(
                        title: "Free Disk Space",
                        value: freeDiskSpaceString,
                        subtitle: "Current available",
                        icon: "internaldrive",
                        color: .indigo
                    )

                    StatCard(
                        title: "Excluded Paths",
                        value: "\(scannerVM.exclusionStore.excludedPaths.count)",
                        subtitle: "Always skipped",
                        icon: "eye.slash",
                        color: .orange
                    )
                }

                if !scannerVM.largeFileHits.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Large File Hunter")
                            .font(.title2.bold())

                        ForEach(scannerVM.largeFileHits.prefix(10)) { hit in
                            LargeFileRow(hit: hit)
                        }

                        Text("Installer files and partial downloads are prioritized automatically.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if !scannerVM.projectBreakdown.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Top Projects by Artifact Size")
                            .font(.title2.bold())

                        ForEach(scannerVM.projectBreakdown.prefix(5), id: \.projectURL) { group in
                            ProjectSummaryRow(
                                name: group.name,
                                totalBytes: group.totalBytes,
                                maxBytes: scannerVM.projectBreakdown.first?.totalBytes ?? 1
                            )
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 15) {
                    Text("Optimization Tips")
                        .font(.title2.bold())

                    InfoBox(
                        title: "Realtime analysis enabled",
                        message: "Cached results load instantly, then DevReclaim refreshes in the background every few minutes.",
                        severity: .info
                    )

                    if let warning = scannerVM.scanWarnings.first {
                        InfoBox(
                            title: "Scan note",
                            message: warning,
                            severity: .warning
                        )
                    }

                    if scannerVM.scanTargets.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No targets identified yet")
                                .font(.headline)
                            Text("DevReclaim scans automatically. You can still press ⌘R to force a fresh pass.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }
                }
            }
            .padding(30)
            .padding(.bottom, 56)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(minWidth: 500)
    }

    private var healthColor: Color {
        switch scannerVM.healthScore {
        case 80...: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    private var scanSubtitle: String? {
        let formatter = RelativeDateTimeFormatter()
        if let lastScanDate = scannerVM.lastScanDate {
            let value = formatter.localizedString(for: lastScanDate, relativeTo: Date())
            if scannerVM.isUsingCachedSnapshot {
                return "Showing cached snapshot from \(value)"
            }
            return "Updated \(value)"
        }
        return nil
    }

    private var freeDiskSpaceString: String {
        guard let values = try? URL(fileURLWithPath: NSHomeDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let capacity = values.volumeAvailableCapacityForImportantUsage else {
            return "—"
        }
        return ByteCountFormatter.string(fromByteCount: capacity, countStyle: .file)
    }
}

// MARK: - Large File Row

struct LargeFileRow: View {
    let hit: LargeFileHit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(ByteCountFormatter.string(fromByteCount: hit.allocatedSizeInBytes, countStyle: .file))
                    .font(.caption.monospacedDigit().bold())
                    .foregroundColor(.primary)

                Text(hit.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if let lastAccessDate = hit.lastAccessDate {
                    Text(RelativeDateTimeFormatter().localizedString(for: lastAccessDate, relativeTo: Date()))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Text(hit.path)
                .font(.caption.monospaced())
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Project Summary Row

struct ProjectSummaryRow: View {
    let name: String
    let totalBytes: Int64
    let maxBytes: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(name, systemImage: "folder.fill")
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor.opacity(0.7))
                        .frame(width: geo.size.width * barFraction)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 4)
    }

    private var barFraction: CGFloat {
        guard maxBytes > 0 else { return 0 }
        return min(1, CGFloat(totalBytes) / CGFloat(maxBytes))
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title.bold())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}
