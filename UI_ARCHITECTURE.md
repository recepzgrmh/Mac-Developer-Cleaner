# DevReclaim: UI Architecture (SwiftUI)

## 🎨 Design Philosophy
DevReclaim follows a **Native-First** approach, adhering strictly to macOS Human Interface Guidelines (HIG). The goal is to provide a tool that feels like a part of the OS, utilizing standard system components and patterns.

## 🏗 Main Layout: 3-Pane Navigation
The application is built around the `NavigationSplitView`, which provides a familiar macOS 3-pane experience:

1. **Sidebar (Primary):** `SidebarView`
   - Navigation categories: Overview, Global Caches, Local Projects, History.
   - Built with `List` and `NavigationLink`.
   - Uses `SidebarItem` enum for type-safe routing.

2. **Content (Secondary):** 
   - Displays a list of scan results based on the sidebar selection.
   - For Global Caches: Lists presets (e.g., npm, Xcode, CocoaPods).
   - For Local Projects: Lists discovered project-level artifacts.
   - For History: `HistoryView` with chronological reports.

3. **Detail (Detail):**
   - Triggered when a specific target or preset is selected from the Content pane.
   - Shows size estimation, risk profile, and the primary "Reclaim" action button.

## 🧠 State & Observation (MVVM)
The UI uses the modern **Swift 5.9+ @Observable** macro for clean data binding without third-party libraries.

- **`ScannerViewModel`:** Manages the lifecycle of scanning tasks. Updates the UI with discovered targets and progress.
- **`ExecutionViewModel`:** Manages the execution state (`idle`, `running`, `completed`, `error`). Handles the "Native Command vs. Trash Fallback" logic and shows modals/prompts.
- **`HistoryViewModel`:** Fetches and parses the `audit-log.json` for the History view.

## 🛠 Key UI Components
- **`MainSplitView`:** The orchestrator that holds the state of the scanner and execution VMs.
- **`SidebarView`:** Uses standard SF Symbols for consistent iconography.
- **`HistoryView`:** Utilizes `ContentUnavailableView` for empty states and `List` with custom cell layouts for reports.
- **Modals:** Triggered via `ExecutionState` to ask for user consent when a native command fails.

## 🧩 Styling & Assets
- **SF Symbols:** All icons are native (e.g., `chart.bar.fill`, `archivebox.fill`, `folder.fill`, `clock.fill`).
- **Typography:** Uses standard Font styles (`.headline`, `.caption`, `.title3`) to ensure accessibility and system integration.
- **Colors:** Leverages standard semantic colors (`.secondary`, `.red`) for light/dark mode compatibility.

## 🚀 Future UI Improvements (v2)
- **Overview Dashboard:** A visual breakdown of disk usage (Charts).
- **Onboarding Flow:** Explaining FDA (Full Disk Access) and least-privilege principles to new users.
- **Advanced Filtering:** Sorting history and scan results by size or date.
