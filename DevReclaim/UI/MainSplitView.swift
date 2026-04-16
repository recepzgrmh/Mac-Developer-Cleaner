import SwiftUI

struct MainSplitView: View {
    @State private var scannerVM = ScannerViewModel()
    @State private var executionVM = ExecutionViewModel()
    @State private var selectedSidebarItem: SidebarItem? = .overview
    @State private var selectedPresetId: String?
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedSidebarItem)
        } content: {
            Group {
                switch selectedSidebarItem {
                case .overview, .none:
                    OverviewDashboardView(scannerVM: scannerVM)
                case .globalPresets:
                    List(scannerVM.presets.filter { $0.category == "global_cache" }, selection: $selectedPresetId) { preset in
                        PresetRowView(
                            preset: preset,
                            target: scannerVM.scanTargets.first(where: { $0.matchingPresetId == preset.id }),
                            isScanning: scannerVM.isScanning
                        )
                    }
                case .localProjects:
                    List(scannerVM.presets.filter { $0.category == "project_artifact" }, selection: $selectedPresetId) { preset in
                        PresetRowView(
                            preset: preset,
                            target: scannerVM.scanTargets.first(where: { $0.matchingPresetId == preset.id }),
                            isScanning: scannerVM.isScanning
                        )
                    }
                case .history:
                    HistoryView()
                }
            }
            .navigationTitle(selectedSidebarItem?.rawValue ?? "DevReclaim")
            .toolbar {
                ToolbarItemGroup {
                    if selectedSidebarItem == .globalPresets || selectedSidebarItem == .localProjects {
                        Button(action: {
                            Task {
                                if let selectedPresetId = selectedPresetId,
                                   let preset = scannerVM.presets.first(where: { $0.id == selectedPresetId }) {
                                    await scannerVM.scan(preset: preset)
                                } else {
                                    await scannerVM.scanAll()
                                }
                            }
                        }) {
                            Label("Scan Now", systemImage: "play.fill")
                        }
                        .disabled(scannerVM.isScanning)
                    }
                }
            }
        } detail: {
            DetailPanelView(
                preset: scannerVM.presets.first(where: { $0.id == selectedPresetId }),
                target: scannerVM.scanTargets.first(where: { $0.matchingPresetId == selectedPresetId }),
                scannerVM: scannerVM,
                executionVM: executionVM
            )
        }
        .onAppear {
            scannerVM.loadPresets()
        }
    }
}

struct DetailPanelView: View {
    let preset: Preset?
    let target: ScanTarget?
    let scannerVM: ScannerViewModel
    let executionVM: ExecutionViewModel
    
    var body: some View {
        if let preset = preset {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // A. Header Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preset.name)
                                    .font(.system(size: 32, weight: .bold))
                                Text(preset.category.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if let target = target {
                                Text(ByteCountFormatter.string(fromByteCount: target.allocatedSizeInBytes, countStyle: .file))
                                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        
                        Text(preset.explanation)
                            .font(.body)
                            .foregroundColor(.primary.opacity(0.8))
                            .lineSpacing(4)
                    }
                    .padding(.bottom, 8)
                    
                    // B. Decision Support Card (Risk & Confidence)
                    HStack(spacing: 16) {
                        DetailSectionCard(title: "Risk Level", icon: "shield.lefthalf.filled") {
                            RiskBadge(level: preset.riskLevel)
                        }
                        
                        DetailSectionCard(title: "Confidence", icon: "target") {
                            Text(preset.reclaimConfidence.rawValue.capitalized)
                                .font(.headline)
                        }
                    }
                    
                    // C. Safety Explanation / Info
                    if preset.riskLevel == .safe {
                        InfoBox(
                            title: "Safe to Reclaim",
                            message: "These files are standard caches. They will be recreated automatically the next time you build or run the associated tool.",
                            severity: .success
                        )
                    } else if preset.riskLevel == .reviewFirst {
                        InfoBox(
                            title: "Review Recommended",
                            message: preset.reviewReason ?? "Deleting these items might require re-downloading dependencies or slower initial builds.",
                            severity: .warning
                        )
                    }
                    
                    // D. Scan/Reclaim Action Card
                    VStack(alignment: .leading, spacing: 16) {
                        if let target = target {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Found at", systemImage: "folder.fill")
                                    .font(.headline)
                                
                                Text(target.url.path)
                                    .font(.subheadline.monospaced())
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.primary.opacity(0.05))
                                    .cornerRadius(8)
                                
                                ReclaimActionCard(target: target, preset: preset, executionVM: executionVM)
                            }
                        } else {
                            Button(action: {
                                Task { await scannerVM.scan(preset: preset) }
                            }) {
                                HStack {
                                    if scannerVM.isScanning {
                                        ProgressView().controlSize(.small).padding(.trailing, 4)
                                    }
                                    Label("Scan & Measure", systemImage: "magnifyingglass")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(scannerVM.isScanning)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    
                    // E. Technical Details (Disclosure)
                    DisclosureGroup("Technical Details") {
                        VStack(alignment: .leading, spacing: 8) {
                            DetailRow(label: "Detection", value: preset.detectionMethod.rawValue)
                            DetailRow(label: "Strategy", value: preset.dryRunStrategy.rawValue)
                            if let cmd = preset.nativeCommand {
                                DetailRow(label: "Command", value: cmd, monospaced: true)
                            }
                            
                            if !executionVM.technicalDetails.isEmpty {
                                Divider().padding(.vertical, 4)
                                Text("Last Execution Log:")
                                    .font(.caption.bold())
                                Text(executionVM.technicalDetails)
                                    .font(.caption)
                                    .monospaced()
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.black.opacity(0.05))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.top, 10)
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(32)
            }
            .alert("Native Command Failed", isPresented: Binding(
                get: { if case .awaitingTrashConsent = executionVM.state { return true } else { return false } },
                set: { _ in }
            )) {
                Button("Cancel", role: .cancel) {
                    executionVM.reset()
                }
                Button("Yes, Move to Trash", role: .destructive) {
                    if case .awaitingTrashConsent(let target) = executionVM.state {
                        Task {
                            await executionVM.executeTrashFallback(target: target, preset: preset)
                        }
                    }
                }
            } message: {
                Text("The native cleanup tool failed. Do you want to move the files to the Trash instead?")
            }
        } else {
            EmptySelectionView()
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var monospaced: Bool = false
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .bold()
                .frame(width: 80, alignment: .leading)
            Text(value)
                .monospaced(monospaced)
        }
    }
}
