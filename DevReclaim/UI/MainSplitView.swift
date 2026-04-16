import SwiftUI

struct MainSplitView: View {
    var scannerVM: ScannerViewModel
    var executionVM: ExecutionViewModel
    @State private var selectedSidebarItem: SidebarItem? = .overview
    @State private var selectedPresetId: String?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedSidebarItem)
        } content: {
            VStack(spacing: 0) {
                // Permission warning banner
                if let warning = scannerVM.permissionWarning {
                    PermissionBannerView(message: warning, actionTitle: "Open Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }

                // Scan progress indicator
                if scannerVM.isScanning {
                    ScanProgressBanner(
                        phase: scannerVM.scanPhase,
                        currentPath: scannerVM.currentScanningPath,
                        completed: scannerVM.scanProgressCompleted,
                        total: scannerVM.scanProgressTotal
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                }

                Group {
                    switch selectedSidebarItem {
                    case .overview, .none:
                        OverviewDashboardView(scannerVM: scannerVM)
                    case .globalPresets:
                        presetList(category: "global_cache")
                    case .localProjects:
                        localProjectsContent
                    case .history:
                        HistoryView()
                    }
                }
            }
            .navigationTitle(selectedSidebarItem?.rawValue ?? "DevReclaim")
            .toolbar {
                ToolbarItemGroup {
                    if selectedSidebarItem == .globalPresets || selectedSidebarItem == .localProjects {
                        Button(action: triggerScan) {
                            Label(
                                scannerVM.isScanning ? "Scanning…" : "Scan Now",
                                systemImage: scannerVM.isScanning ? "arrow.triangle.2.circlepath" : "play.fill"
                            )
                        }
                        .disabled(scannerVM.isScanning)
                        .keyboardShortcut("r", modifiers: .command)
                        .help("Scan selected preset or all presets (⌘R)")
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

    // MARK: - Helpers

    private func triggerScan() {
        Task {
            if let id = selectedPresetId,
               let preset = scannerVM.presets.first(where: { $0.id == id }) {
                await scannerVM.scan(preset: preset)
            } else {
                await scannerVM.scanAll()
            }
        }
    }

    private func presetList(category: String) -> some View {
        List(
            scannerVM.presets.filter { $0.category == category },
            selection: $selectedPresetId
        ) { preset in
            PresetRowView(
                preset: preset,
                target: scannerVM.scanTargets.first(where: { $0.matchingPresetId == preset.id }),
                isScanning: scannerVM.isScanning
            )
            .contextMenu {
                if let target = scannerVM.scanTargets.first(where: { $0.matchingPresetId == preset.id }) {
                    exclusionContextMenu(for: target)
                }
            }
        }
    }

    @ViewBuilder
    private var localProjectsContent: some View {
        if scannerVM.projectBreakdown.isEmpty {
            presetList(category: "project_artifact")
        } else {
            List(selection: $selectedPresetId) {
                ForEach(scannerVM.projectBreakdown, id: \.projectURL) { group in
                    Section {
                        ForEach(group.targets) { target in
                            if let preset = scannerVM.presets.first(where: { $0.id == target.matchingPresetId }) {
                                PresetRowView(
                                    preset: preset,
                                    target: target,
                                    isScanning: scannerVM.isScanning
                                )
                                .tag(preset.id)
                                .contextMenu { exclusionContextMenu(for: target) }
                            }
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Label(group.name, systemImage: "folder.fill")
                                .font(.subheadline.bold())
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .layoutPriority(1)
                            Spacer(minLength: 4)
                            Text(ByteCountFormatter.string(fromByteCount: group.totalBytes, countStyle: .file))
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                                .fixedSize()
                        }
                    }
                }

                if scannerVM.skippedExcludedCount > 0 {
                    Section {
                        Label("\(scannerVM.skippedExcludedCount) target(s) hidden by exclusion rules.", systemImage: "eye.slash")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func exclusionContextMenu(for target: ScanTarget) -> some View {
        if scannerVM.exclusionStore.isExcluded(target.url) {
            Button("Remove from Exclusions") {
                scannerVM.exclusionStore.unexclude(target.url)
            }
        } else {
            Button("Always Skip This Path", role: .destructive) {
                scannerVM.exclusionStore.exclude(target.url)
                scannerVM.scanTargets.removeAll { $0.url == target.url }
            }
        }
    }
}

// MARK: - Scan Progress Banner

struct ScanProgressBanner: View {
    let phase: ScannerViewModel.ScanPhase
    let currentPath: String?
    let completed: Int
    let total: Int

    var body: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)

            VStack(alignment: .leading, spacing: 2) {
                Text(phaseLabel)
                    .font(.subheadline.bold())
                if let path = currentPath {
                    Text(path)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            if total > 0 {
                Text("\(completed) / \(total)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.07))
        .cornerRadius(8)
    }

    private var phaseLabel: String {
        switch phase {
        case .discovery: return "Discovering targets…"
        case .measuring: return "Measuring sizes…"
        default: return "Scanning…"
        }
    }
}

// MARK: - Detail Panel

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

                    // B. Decision Support Cards — adaptive grid so they never get squashed
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
                        DetailSectionCard(title: "Risk Level", icon: "shield.lefthalf.filled") {
                            RiskBadge(level: preset.riskLevel)
                        }

                        DetailSectionCard(title: "Confidence", icon: "target") {
                            Text(preset.reclaimConfidence.rawValue.capitalized)
                                .font(.headline)
                                .lineLimit(1)
                        }

                        if let tool = preset.requiresToolInstalled {
                            let available = scannerVM.toolAvailability[tool] ?? false
                            DetailSectionCard(title: "Tool", icon: "wrench.and.screwdriver") {
                                Label(available ? tool : "\(tool) not found",
                                      systemImage: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(available ? .green : .red)
                                    .font(.caption.bold())
                                    .lineLimit(1)
                            }
                        }
                    }

                    // C. Safety info
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

                                // Disk freed indicator (post-execution)
                                if executionVM.freedDiskBytes > 0 {
                                    HStack {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .foregroundColor(.green)
                                        Text("Disk space freed: \(ByteCountFormatter.string(fromByteCount: executionVM.freedDiskBytes, countStyle: .file))")
                                            .font(.subheadline.bold())
                                            .foregroundColor(.green)
                                    }
                                    .padding(.vertical, 4)
                                }

                                ReclaimActionCard(
                                    target: target,
                                    preset: preset,
                                    executionVM: executionVM
                                )
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
                            .keyboardShortcut("r", modifiers: .command)
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
                Button("Cancel", role: .cancel) { executionVM.reset() }
                Button("Yes, Move to Trash", role: .destructive) {
                    if case .awaitingTrashConsent(let target) = executionVM.state {
                        Task { await executionVM.executeTrashFallback(target: target, preset: preset) }
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

// MARK: - Detail Row

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
