# DevReclaim UI Code Summary

Bu dosya DevReclaim macOS uygulamasının güncellenmiş (Refactored) UI kodlarını, modüler bileşenlerini ve modern ViewModel yapısını içermektedir.

---

## 1. UI Architecture Documentation (Updated)
```markdown
# DevReclaim: UI Architecture (SwiftUI)

## 🎨 Design Philosophy
DevReclaim follows a **Premium Native-First** approach. The UI is designed to feel like an integrated part of macOS (similar to Xcode or Finder), utilizing card-based layouts, unified toolbars, and clear visual hierarchy.

## 🏗 Modular Layout: 3-Pane Split View
The application uses `NavigationSplitView` with a refactored component-based architecture:

1. **Sidebar (Primary):** `SidebarView`
   - Divided into **Workspace** (Overview, Global Caches, Local Projects) and **Activity** (History).
   - Uses refined SF Symbols (e.g., `internaldrive`, `archivebox`, `hammer`).

2. **Content (Secondary):** 
   - **Overview Dashboard:** `OverviewDashboardView` - Visual metrics and optimization tips.
   - **Preset Lists:** Lists of `PresetRowView` instances, showing real-time size measurements and risk badges.
   - **History:** `HistoryView` - Now uses a native macOS `Table` for structured data.

3. **Detail (Detail):** `DetailPanelView`
   - **Header Card:** Large titles and primary metrics.
   - **Decision Support:** Risk level and confidence badges in dedicated cards.
   - **Action Card:** Context-aware "Reclaim Space" button with execution feedback.
   - **Technical Details:** Disclosure group for technical logs and command info.

## 🧠 State & Observation (MVVM)
- **`ScannerViewModel`:** Tracks `scanPhase` (discovery, measuring), `totalReclaimableBytes`, and global scanning state.
- **`ExecutionViewModel`:** Manages a refined `ExecutionState` (idle, runningNative, awaitingTrashConsent, completed, failed). Separates user-facing status from technical logs.
- **`HistoryViewModel`:** Manages the chronological display of past reclamation reports.

## 🛠 Key UI Components (Refactored)
- **`PresetRowView`:** Compact summary of a preset's status in the middle list.
- **`InfoBox`:** Versatile banner for info, success, warning, and error states.
- **`RiskBadge`:** Color-coded indicator for safety levels.
- **`EmptySelectionView`:** Clean placeholder for empty detail panes.
- **`StatCard`:** Reusable card for dashboard metrics.
```

---

## 2. App Entry Point (DevReclaimApp.swift)
```swift
import SwiftUI

@main
struct DevReclaimApp: App {
    var body: some Scene {
        WindowGroup {
            MainSplitView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
    }
}
```

---

## 3. Main Layout & Orchestration (MainSplitView.swift)
```swift
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
```

---

## 4. Common Components (Highlights)

### PresetRowView.swift
```swift
struct PresetRowView: View {
    let preset: Preset
    let target: ScanTarget?
    let isScanning: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Category Icon, Name, Explanation, Size, RiskBadge...
        }
    }
}
```

### RiskBadge.swift
```swift
struct RiskBadge: View {
    let level: RiskLevel
    var body: some View {
        // Color-coded text with subtle background and stroke
    }
}
```

### InfoBox.swift
```swift
struct InfoBox: View {
    let title: String
    let message: String
    let severity: InfoBoxSeverity
    let actionTitle: String?
    let action: (() -> Void)?
    // Supports info, success, warning, error with optional trailing buttons
}
```

---

## 5. ViewModels (Logic)

### ScannerViewModel.swift
```swift
@Observable
class ScannerViewModel {
    var scanPhase: ScanPhase = .idle
    var totalReclaimableBytes: Int64 { ... }
    var isScanning = false
    // Handles multi-target discovery and volume calculation
}
```

### ExecutionViewModel.swift
```swift
@Observable
class ExecutionViewModel {
    enum ExecutionState { case idle, runningNative, awaitingTrashConsent, runningTrash, completed(ExecutionReport), failed(String) }
    var userFacingStatus: String = ""
    var technicalDetails: String = ""
    // Orchestrates NativeCommandExecutor and TrashExecutor with audit logging
}
```
