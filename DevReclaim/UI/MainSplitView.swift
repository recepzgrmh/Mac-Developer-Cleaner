import SwiftUI

private enum DetailSelection: Hashable {
    case preset(String)
    case targetKey(String)
}

private enum ProjectSortOption: String, CaseIterable, Identifiable {
    case sizeDescending = "Largest First"
    case sizeAscending = "Smallest First"
    case nameAscending = "Name A-Z"
    case nameDescending = "Name Z-A"

    var id: String { rawValue }
}

private struct FilteredProjectGroup {
    let projectURL: URL
    let name: String
    let targets: [ScanTarget]
    let totalBytes: Int64
}

struct MainSplitView: View {
    var scannerVM: ScannerViewModel
    var executionVM: ExecutionViewModel
    @State private var selectedSidebarItem: SidebarItem? = .overview
    @State private var selectedDetailSelection: DetailSelection?
    @State private var projectSearchText = ""
    @State private var selectedProjectPresetFilterId = "all"
    @State private var projectSortOption: ProjectSortOption = .sizeDescending
    @State private var filteredProjectGroups: [FilteredProjectGroup] = []
    @State private var filteredProjectTargetCount = 0
    @AppStorage("devreclaim.hasCompletedOnboarding") private var hasCompletedOnboarding = false

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
                    case .systemCaches:
                        presetList(category: "system_cache")
                    case .localProjects:
                        localProjectsContent
                    case .history:
                        HistoryView()
                    case .settings:
                        SettingsView(scannerVM: scannerVM)
                    case .about:
                        AboutView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .safeAreaPadding(.top, 6)
            .navigationTitle(selectedSidebarItem?.rawValue ?? "DevReclaim")
            .toolbar {
                ToolbarItemGroup {
                    if !scannerVM.isScanning {
                        let summary = toolbarSummary
                        if !summary.isEmpty {
                            Text(summary)
                                .font(.subheadline.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                    }
                    Button(action: triggerScan) {
                        Label(
                            scannerVM.isScanning ? "Scanning…" : "Scan All",
                            systemImage: scannerVM.isScanning ? "arrow.triangle.2.circlepath" : "arrow.clockwise"
                        )
                    }
                    .disabled(scannerVM.isScanning)
                    .keyboardShortcut("r", modifiers: .command)
                    .help("Scan all presets (⌘R)")
                }
            }
        } detail: {
            DetailPanelView(
                preset: selectedPreset,
                target: selectedTarget,
                scannerVM: scannerVM,
                executionVM: executionVM
            )
        }
        .onAppear {
            scannerVM.loadPresets()
        }
        .task(id: projectFilterRefreshToken) {
            await recomputeFilteredProjects()
        }
        .onChange(of: selectedSidebarItem) { _, newItem in
            guard newItem == .globalPresets || newItem == .systemCaches else { return }
            Task { await scannerVM.refreshFastCaches() }
        }
        .sheet(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { shown in if !shown { hasCompletedOnboarding = true } }
        )) {
            OnboardingView(
                onComplete: {
                    hasCompletedOnboarding = true
                    Task { await scannerVM.scanAll() }
                },
                onFullHomeScanSelected: { enabled in
                    scannerVM.fullHomeProjectScanEnabled = enabled
                }
            )
        }
    }

    // MARK: - Helpers

    private func triggerScan() {
        Task { await scannerVM.scanAll() }
    }

    private var toolbarSummary: String {
        var parts: [String] = []
        if scannerVM.totalReclaimableBytes > 0 {
            parts.append(ByteCountFormatter.string(fromByteCount: scannerVM.totalReclaimableBytes, countStyle: .file) + " reclaimable")
        }
        if let lastScanDate = scannerVM.lastScanDate {
            parts.append(RelativeDateTimeFormatter().localizedString(for: lastScanDate, relativeTo: Date()))
        }
        return parts.joined(separator: " • ")
    }

    private var projectPresetFilterOptions: [(id: String, title: String)] {
        let projectPresets = scannerVM.presets
            .filter { $0.category == "project_artifact" }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { ($0.id, $0.name) }
        return [("all", "All Artifacts")] + projectPresets
    }

    private var projectFilterRefreshToken: String {
        "\(scannerVM.projectBreakdownRevision)|\(projectSearchText)|\(selectedProjectPresetFilterId)|\(projectSortOption.rawValue)"
    }

    private var isProjectFilterActive: Bool {
        selectedProjectPresetFilterId != "all" || !projectSearchText.isEmpty || projectSortOption != .sizeDescending
    }

    @ViewBuilder
    private var projectFilterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                TextField("Filter by project, path, or artifact", text: $projectSearchText)
                    .textFieldStyle(.roundedBorder)

                Picker("Artifact", selection: $selectedProjectPresetFilterId) {
                    ForEach(projectPresetFilterOptions, id: \.id) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .pickerStyle(.menu)

                Picker("Sort", selection: $projectSortOption) {
                    ForEach(ProjectSortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)

                if isProjectFilterActive {
                    Button("Reset") {
                        projectSearchText = ""
                        selectedProjectPresetFilterId = "all"
                        projectSortOption = .sizeDescending
                    }
                    .buttonStyle(.borderless)
                }
            }

            Text("\(filteredProjectGroups.count) project(s), \(filteredProjectTargetCount) target(s)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var selectedTarget: ScanTarget? {
        guard case .targetKey(let key) = selectedDetailSelection else { return nil }
        return scannerVM.scanTargets.first(where: { $0.identityKey == key })
    }

    private var selectedPreset: Preset? {
        switch selectedDetailSelection {
        case .preset(let presetId):
            return scannerVM.presetById[presetId]
        case .targetKey(let key):
            guard let target = scannerVM.scanTargets.first(where: { $0.identityKey == key }),
                  let presetId = target.matchingPresetId else {
                return nil
            }
            return scannerVM.presetById[presetId]
        case .none:
            return nil
        }
    }

    private func detailSelectionTag(for preset: Preset, target: ScanTarget?) -> DetailSelection {
        if let target {
            return .targetKey(target.identityKey)
        }
        return .preset(preset.id)
    }

    private func presetList(category: String) -> some View {
        let all = scannerVM.presets.filter { $0.category == category }
        let visible = all.filter { !isToolHidden($0) }
        let hiddenCount = all.count - visible.count

        return List(selection: $selectedDetailSelection) {
            ForEach(visible) { preset in
                let target = scannerVM.scanTargets.first(where: { $0.matchingPresetId == preset.id })
                PresetRowView(
                    preset: preset,
                    target: target,
                    isScanning: scannerVM.isScanning
                )
                .tag(detailSelectionTag(for: preset, target: target))
                .contextMenu {
                    if let target {
                        exclusionContextMenu(for: target)
                    }
                }
            }

            if hiddenCount > 0 {
                let missingTools = Array(Set(
                    all.filter { isToolHidden($0) }.compactMap { $0.requiresToolInstalled }
                )).sorted()
                Section {
                    Label(
                        "\(missingTools.joined(separator: ", ")) not found — \(hiddenCount) preset\(hiddenCount == 1 ? "" : "s") hidden.",
                        systemImage: "eye.slash"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
    }

    /// Returns true when a preset's required tool is confirmed absent from the system.
    /// Presets whose tool availability is still unknown (nil) are shown to avoid premature hiding.
    private func isToolHidden(_ preset: Preset) -> Bool {
        guard let tool = preset.requiresToolInstalled else { return false }
        return scannerVM.toolAvailability[tool] == false
    }

    @ViewBuilder
    private var localProjectsContent: some View {
        if scannerVM.projectBreakdown.isEmpty {
            presetList(category: "project_artifact")
        } else {
            VStack(spacing: 0) {
                projectFilterBar

                if filteredProjectGroups.isEmpty {
                    ContentUnavailableView(
                        "No Matching Projects",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Try clearing filters or running a fresh scan.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedDetailSelection) {
                        ForEach(filteredProjectGroups, id: \.projectURL) { group in
                            Section {
                                ForEach(group.targets) { target in
                                    if let presetId = target.matchingPresetId,
                                       let preset = scannerVM.presetById[presetId] {
                                        PresetRowView(
                                            preset: preset,
                                            target: target,
                                            isScanning: scannerVM.isScanning
                                        )
                                        .tag(DetailSelection.targetKey(target.identityKey))
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
                scannerVM.removeTargetFromResults(target)
            }
        }
    }

    @MainActor
    private func recomputeFilteredProjects() async {
        let refreshToken = projectFilterRefreshToken
        let snapshot = scannerVM.projectBreakdown
        let selectedPresetId = selectedProjectPresetFilterId
        let search = projectSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sortOption = projectSortOption
        let presetNameById = scannerVM.presetById.reduce(into: [String: String]()) { partialResult, entry in
            partialResult[entry.key] = entry.value.name.lowercased()
        }

        let result = await Task.detached(priority: .utility) { () -> (groups: [FilteredProjectGroup], targetCount: Int) in
            var groups: [FilteredProjectGroup] = []

            for group in snapshot {
                let filteredTargets = group.targets.filter { target in
                    if selectedPresetId != "all", target.matchingPresetId != selectedPresetId {
                        return false
                    }

                    guard !search.isEmpty else { return true }
                    let presetName = target.matchingPresetId.flatMap { presetNameById[$0] } ?? ""
                    return group.name.lowercased().contains(search)
                        || target.url.lastPathComponent.lowercased().contains(search)
                        || target.url.path.lowercased().contains(search)
                        || presetName.contains(search)
                }

                guard !filteredTargets.isEmpty else { continue }
                let totalBytes = filteredTargets.reduce(Int64(0)) { $0 + $1.allocatedSizeInBytes }
                groups.append(
                    FilteredProjectGroup(
                        projectURL: group.projectURL,
                        name: group.name,
                        targets: filteredTargets,
                        totalBytes: totalBytes
                    )
                )
            }

            switch sortOption {
            case .sizeDescending:
                groups.sort { $0.totalBytes > $1.totalBytes }
            case .sizeAscending:
                groups.sort { $0.totalBytes < $1.totalBytes }
            case .nameAscending:
                groups.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            case .nameDescending:
                groups.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
            }

            let targetCount = groups.reduce(0) { $0 + $1.targets.count }
            return (groups, targetCount)
        }.value

        guard refreshToken == projectFilterRefreshToken else { return }
        filteredProjectGroups = result.groups
        filteredProjectTargetCount = result.targetCount
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

private struct DeleteConfirmationRequest: Identifiable {
    let id = UUID()
    let target: ScanTarget
    let preset: Preset
    let preview: DryRunPreview?
}

struct DetailPanelView: View {
    let preset: Preset?
    let target: ScanTarget?
    let scannerVM: ScannerViewModel
    let executionVM: ExecutionViewModel
    @State private var isPreparingDeleteConfirmation = false
    @State private var deleteConfirmationRequest: DeleteConfirmationRequest?

    var body: some View {
        if let preset = preset {
            ScrollView(showsIndicators: true) {
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

                        if let target = target {
                            DetailSectionCard(title: "Last Used", icon: "clock") {
                                Text(target.relativeLastAccessDescription ?? "Unknown")
                                    .font(.headline)
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
                                    executionVM: executionVM,
                                    onReclaimRequested: {
                                        requestDeleteConfirmation(for: target, preset: preset)
                                    },
                                    isPreparingConfirmation: isPreparingDeleteConfirmation
                                )

                                DryRunPreviewSection(target: target, scannerVM: scannerVM)
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
                            DetailRow(label: "Cleanup", value: "Permanent Delete", monospaced: false)

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
                .padding(.bottom, 56)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .sheet(item: $deleteConfirmationRequest) { request in
                DeleteConfirmationSheet(
                    request: request,
                    isExecuting: executionVM.state == .runningDelete,
                    onCancel: {
                        deleteConfirmationRequest = nil
                    },
                    onConfirm: {
                        deleteConfirmationRequest = nil
                        Task {
                            await executionVM.execute(target: request.target, preset: request.preset)
                            if case .completed = executionVM.state {
                                scannerVM.removeTargetFromResults(request.target)
                            }
                        }
                    }
                )
            }
        } else {
            EmptySelectionView()
        }
    }

    private func requestDeleteConfirmation(for target: ScanTarget, preset: Preset) {
        guard !isPreparingDeleteConfirmation else { return }
        isPreparingDeleteConfirmation = true

        Task {
            defer { isPreparingDeleteConfirmation = false }
            await scannerVM.loadDryRunPreview(for: target)
            let preview = scannerVM.dryRunPreview(for: target)
            deleteConfirmationRequest = DeleteConfirmationRequest(
                target: target,
                preset: preset,
                preview: preview
            )
        }
    }
}

private struct DeleteConfirmationSheet: View {
    let request: DeleteConfirmationRequest
    let isExecuting: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Delete Permanently?")
                .font(.title2.bold())

            Text("This action cannot be undone. The following items will be removed from disk:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Text(request.preset.name)
                    .font(.subheadline.bold())
                Text(ByteCountFormatter.string(fromByteCount: request.target.allocatedSizeInBytes, countStyle: .file))
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            if let preview = request.preview, !preview.items.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(preview.items.prefix(20)) { item in
                            HStack(spacing: 8) {
                                Image(systemName: item.isDirectory ? "folder" : "doc")
                                    .foregroundColor(.secondary)
                                Text(item.path)
                                    .font(.caption.monospaced())
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer(minLength: 8)
                                if !item.isDirectory {
                                    Text(ByteCountFormatter.string(fromByteCount: item.allocatedSizeInBytes, countStyle: .file))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 220)
                .padding(10)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(8)

                if preview.isTruncated {
                    Text("Showing first \(min(20, preview.items.count)) items.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Text(request.target.url.path)
                    .font(.caption.monospaced())
                    .lineLimit(3)
                    .truncationMode(.middle)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(8)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Delete Permanently", role: .destructive, action: onConfirm)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isExecuting)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 380)
    }
}

// MARK: - Dry-Run Preview

struct DryRunPreviewSection: View {
    let target: ScanTarget
    let scannerVM: ScannerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Dry-Run Preview", systemImage: "list.bullet.clipboard")
                    .font(.headline)
                Spacer()
                Button("Refresh") {
                    Task { await scannerVM.loadDryRunPreview(for: target, forceRefresh: true) }
                }
                .buttonStyle(.borderless)
            }

            if scannerVM.isLoadingDryRunPreview(for: target) {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Preparing preview...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let preview = scannerVM.dryRunPreview(for: target) {
                HStack(spacing: 12) {
                    Text("\(preview.totalItems) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: preview.estimatedTotalBytes, countStyle: .file))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(preview.items.prefix(12)) { item in
                        HStack(spacing: 8) {
                            Image(systemName: item.isDirectory ? "folder" : "doc")
                                .foregroundColor(.secondary)
                            Text(item.path)
                                .font(.caption.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 8)
                            if !item.isDirectory {
                                Text(ByteCountFormatter.string(fromByteCount: item.allocatedSizeInBytes, countStyle: .file))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(10)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(8)

                if preview.isTruncated {
                    Text("Showing first \(preview.items.count) paths.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No preview generated yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .task(id: target.url.path) {
            await scannerVM.loadDryRunPreview(for: target)
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
