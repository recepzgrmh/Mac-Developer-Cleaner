import SwiftUI

struct MainSplitView: View {
    @State private var scannerVM = ScannerViewModel()
    @State private var executionVM = ExecutionViewModel()
    @State private var selectedSidebarItem: SidebarItem? = .globalPresets
    @State private var selectedPresetId: String?
    @State private var selectedTargetId: UUID?
    
    var body: some View {
        NavigationSplitView {
            // Sidebar (Pane 1)
            SidebarView(selection: $selectedSidebarItem)
        } content: {
            // Middle List (Pane 2)
            Group {
                switch selectedSidebarItem {
                case .globalPresets:
                    List(scannerVM.presets, selection: $selectedPresetId) { preset in
                        HStack {
                            Text(preset.name)
                            Spacer()
                            if let target = scannerVM.scanTargets.first(where: { $0.matchingPreset?.id == preset.id }) {
                                Text("\(target.allocatedSizeInBytes / 1_000_000) MB")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                case .localProjects:
                    Text("Local Projects Scanning... (Coming Soon)")
                case .history:
                    HistoryView()
                case .overview, .none:
                    Text("Overview Statistics")
                }
            }
            .navigationTitle(selectedSidebarItem?.rawValue ?? "")
        } detail: {
            // Detail Panel (Pane 3)
            DetailPanelView(
                preset: scannerVM.presets.first(where: { $0.id == selectedPresetId }),
                target: scannerVM.scanTargets.first(where: { $0.matchingPreset?.id == selectedPresetId }),
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
        VStack {
            if let preset = preset {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(preset.name).font(.largeTitle).bold()
                        Text(preset.explanation).foregroundColor(.secondary)
                        
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Risk Level").font(.headline)
                                RiskBadge(level: preset.riskLevel)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Confidence").font(.headline)
                                Text(preset.reclaimConfidence.rawValue.capitalized)
                            }
                        }
                        
                        if let target = target {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Scan Result").font(.headline)
                                HStack {
                                    Text("Path:").bold()
                                    Text(target.url.path).lineLimit(1).truncationMode(.middle)
                                }
                                HStack {
                                    Text("Size:").bold()
                                    Text("\(target.allocatedSizeInBytes / 1_000_000) MB")
                                }
                                
                                Button(action: {
                                    Task {
                                        await executionVM.execute(target: target)
                                    }
                                }) {
                                    HStack {
                                        if case .runningNative = executionVM.state {
                                            ProgressView().controlSize(.small).padding(.trailing, 5)
                                        }
                                        Text("Reclaim Space")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                                .disabled(executionVM.state == .runningNative || executionVM.state == .runningTrash)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        } else {
                            Button("Scan & Measure") {
                                Task {
                                    await scannerVM.scan(preset: preset)
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(scannerVM.isScanning)
                        }
                        
                        if !executionVM.logMessage.isEmpty {
                            Text(executionVM.logMessage)
                                .font(.caption)
                                .monospaced()
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.black.opacity(0.05))
                                .cornerRadius(5)
                        }
                    }
                    .padding()
                }
            } else {
                Text("Select an item to see details")
                    .foregroundColor(.secondary)
            }
        }
        .alert("Native Command Failed", isPresented: Binding(
            get: { if case .failedWaitingForTrashConsent = executionVM.state { return true } else { return false } },
            set: { _ in }
        )) {
            Button("Cancel", role: .cancel) {
                executionVM.state = .idle
            }
            Button("Yes, Move to Trash", role: .destructive) {
                if case .failedWaitingForTrashConsent(let target) = executionVM.state {
                    Task {
                        await executionVM.executeTrashFallback(target: target)
                    }
                }
            }
        } message: {
            Text("The native cleanup tool failed. Do you want to move the files to the Trash instead?")
        }
    }
}

struct RiskBadge: View {
    let level: RiskLevel
    
    var color: Color {
        switch level {
        case .safe: return .green
        case .usuallySafe: return .blue
        case .reviewFirst: return .orange
        case .neverAuto: return .red
        }
    }
    
    var body: some View {
        Text(level.rawValue.capitalized)
            .font(.caption2).bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}
