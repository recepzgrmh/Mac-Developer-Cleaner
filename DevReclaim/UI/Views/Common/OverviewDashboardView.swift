import SwiftUI

struct OverviewDashboardView: View {
    let scannerVM: ScannerViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Storage Overview")
                    .font(.largeTitle.bold())
                
                // Quick Stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
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
                        title: "Available Presets",
                        value: "\(scannerVM.presets.count)",
                        icon: "list.bullet.indent",
                        color: .orange
                    )
                }
                
                // Recent Scans or Tips
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
                            Text("Select a category from the sidebar and start scanning.")
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
}

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
