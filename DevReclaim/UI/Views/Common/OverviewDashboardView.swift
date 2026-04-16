import SwiftUI

struct OverviewDashboardView: View {
    let scannerVM: ScannerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Storage Overview")
                    .font(.largeTitle.bold())

                // Quick Stats
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 16
                ) {
                    StatCard(
                        title: "Reclaimable",
                        value: ByteCountFormatter.string(fromByteCount: scannerVM.totalReclaimableBytes, countStyle: .file),
                        icon: "leaf.fill",
                        color: .green
                    )

                    StatCard(
                        title: "Found Targets",
                        value: "\(scannerVM.scanTargets.count)",
                        icon: "target",
                        color: .blue
                    )

                    StatCard(
                        title: "Free Disk Space",
                        value: freeDiskSpaceString,
                        icon: "internaldrive",
                        color: .purple
                    )

                    StatCard(
                        title: "Excluded Paths",
                        value: "\(scannerVM.exclusionStore.excludedPaths.count)",
                        icon: "eye.slash",
                        color: .orange
                    )
                }

                // Per-project summary (if any project artifacts scanned)
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

                // Tips / empty state
                VStack(alignment: .leading, spacing: 15) {
                    Text("Optimization Tips")
                        .font(.title2.bold())

                    InfoBox(
                        title: "Freeing up space",
                        message: "Running a full scan of global caches often identifies gigabytes of redundant data from Xcode and package managers.",
                        severity: .info
                    )

                    if scannerVM.scanTargets.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No targets identified yet")
                                .font(.headline)
                            Text("Select a category from the sidebar and press ⌘R to scan.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }
                }
            }
            .padding(30)
        }
        .frame(minWidth: 500)
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
