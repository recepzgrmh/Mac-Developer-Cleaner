<p align="center">
  <img src="assets/app_icon.png" width="128" height="128" alt="Mac-Developer-Cleaner Logo">
</p>

# Mac-Developer-Cleaner (formerly DevReclaim)

## 🎯 Project Essence
**Mac-Developer-Cleaner** is a native macOS utility built with **SwiftUI** and **Swift 5.9+**. Its mission is to reclaim disk space by safely cleaning developer artifacts (npm, Xcode, Flutter, etc.) while maintaining a minimal footprint (<15MB).

## 🛠 Tech Stack & Architecture
- **Framework:** SwiftUI (@Observable macro based)
- **Project Structure:** Swift Package Manager (SPM). **Open via `Package.swift`**.
- **Engine:** Foundation-based asynchronous scanning and execution.
- **Ruleset:** Follows a strict "Native-First, Trash-Fallback" logic with explicit user consent.

## 🧠 Critical AI Context (Read before editing)

### 1. Swift 6 & Async Contexts
- **File Enumeration:** In `ScannerService.swift`, always use `while let fileURL = enumerator.nextObject() as? URL` instead of `for case let` loops. The latter triggers "makeIterator is unavailable from asynchronous contexts" errors in Swift 6.
- **Redundant Try:** Functions in `ScannerService` are optimized; avoid adding `try await` where the underlying logic is non-throwing or handled via `Task.detached`.

### 2. State Management & Equatable
- **ExecutionState:** The `ExecutionState` enum in `ExecutionViewModel.swift` has associated values. It MUST implement `Equatable` manually (which it currently does) to allow UI state comparisons in `MainSplitView`.

### 3. Window Management
- **Activation Policy:** To ensure the app window appears on launch when run via Xcode/SPM, an `AppDelegate` with `NSApp.activate(ignoringOtherApps: true)` and `makeKeyAndOrderFront` is used in `DevReclaimApp.swift`. Do not remove this unless implementing a different native lifecycle.

### 4. Safety & Guardrails
- **.git Boundary:** The scanner must NEVER treat a `.git` root as a cleanup target. It skips descendants of any `.git` directory to prevent repository corruption.
- **Trash Fallback:** If a `NativeCommandExecutor` fails, the app must transition to `.failedWaitingForTrashConsent` state to prompt the user. NEVER fallback to `FileManager.trashItem` silently.

## 🚀 How to Build & Package
1. Open `Package.swift` in Xcode.
2. Select **My Mac** as the destination.
3. Build/Run with `Cmd + R`.
4. To create a release DMG, run: `bash scripts/package.sh` (ensure a Release `.app` is in the root).

## 📂 Key Files Map
- `DevReclaim/Core/Engine/`: The brain (Scanner, Executor).
- `DevReclaim/UI/ViewModels/`: Logic for views.
- `DevReclaim/UI/Views/`: Native SwiftUI components.
- `_bmad-output/planning-artifacts/`: Source of truth for requirements (PRD, Spec).
