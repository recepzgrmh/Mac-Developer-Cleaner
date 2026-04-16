# DevReclaim: UI Architecture (SwiftUI)

## 🎨 Design Philosophy
DevReclaim adheres to a **Premium Native-First** philosophy. We follow the macOS Human Interface Guidelines (HIG) to ensure the tool feels like a first-class citizen of the OS. Key principles include:
- **Clarity:** Important actions (Reclaim) and risks (Risk Levels) are visually distinct.
- **Feedback:** Real-time progress indicators during scanning and execution.
- **Safety:** Destructive actions require confirmation and provide clear explanations of what will happen.

## 🏗 Main Layout: Modular 3-Pane Navigation
The application utilizes `NavigationSplitView` to provide a standard macOS 3-pane experience, now refactored for better maintainability:

1. **Sidebar (Primary):** `SidebarView`
   - **Workspace Section:** Overview, Global Caches, Local Projects.
   - **Activity Section:** History.
   - Organized into logical sections for better focus.

2. **Content (Secondary):** 
   - **Overview Dashboard:** `OverviewDashboardView` provides high-level metrics (Total reclaimable, found targets).
   - **Preset List:** Displays a filtered list of presets based on sidebar selection, using `PresetRowView` for consistent metadata display.
   - **History:** `HistoryView` uses a native macOS `Table` for structured execution reports.

3. **Detail (Detail):** `DetailPanelView`
   - A card-based layout providing decision support:
     - **Header:** Title, category, and current size.
     - **Risk & Confidence:** Visual badges for risk level and measurement confidence.
     - **Action Card:** The primary `ReclaimActionCard` handles the execution flow.
     - **Technical Details:** A disclosure group for power users needing technical logs.

## 🧠 State Management (MVVM)
Utilizing **Swift 5.9+ @Observable** for efficient, boilerplate-free state propagation.

- **`ScannerViewModel`:** 
  - Orchestrates `ScannerService`.
  - Manages discovery phases and volume calculations.
  - Exposes global metrics like `totalReclaimableBytes`.
- **`ExecutionViewModel`:** 
  - Manages the execution lifecycle through distinct states: `.idle`, `.runningNative`, `.awaitingTrashConsent`, `.completed`, `.failed`.
  - Bridges the UI with `NativeCommandExecutor` and `TrashExecutor`.
- **`HistoryViewModel`:** 
  - Interacts with `AuditLogger` to provide a chronological list of actions.

## 🛠 Key Modular Components
- **`PresetRowView`:** Reusable row for presets in the middle pane.
- **`RiskBadge`:** Semantic color-coded badge for safety assessment.
- **`InfoBox`:** Flexible notification component (info, success, warning, error).
- **`EmptySelectionView`:** Native-feeling placeholder for empty states.

## 🧩 Styling & System Integration
- **SF Symbols:** Carefully chosen semantically correct icons (e.g., `internaldrive`, `archivebox`, `hammer`).
- **Typography:** Uses dynamic type styles (`.largeTitle`, `.headline`, `.caption`) for accessibility.
- **Window Management:** Uses `.unifiedCompact` toolbar style and defined minimum sizes for a stable window experience.
