<p align="center">
  <img src="assets/app_icon.png" width="128" height="128" alt="DevReclaim Logo">
</p>

# DevReclaim (formerly Mac-Developer-Cleaner)

## 🎯 Project Essence
**DevReclaim** is a lightweight, native macOS utility built with **SwiftUI** and **Swift 5.9+**. It reclaims disk space by safely cleaning developer-specific artifacts (npm, Xcode, CocoaPods, etc.) while maintaining a minimal footprint (<15MB) and premium UX.

## 🛠 Tech Stack & Architecture
- **Framework:** SwiftUI (@Observable macro based).
- **Architecture:** Modular MVVM with specialized card-based UI.
- **Project Structure:** Swift Package Manager (SPM). **Open via `Package.swift`**.
- **Engine:** Foundation-based asynchronous scanning and execution.
- **Ruleset:** "Native-First, Trash-Fallback" logic with explicit user consent and risk-based decision support.

## 🧠 Critical AI Context (Read before editing)

### 1. Swift 6 & Async Contexts
- **File Enumeration:** In `ScannerService.swift`, always use `while let fileURL = enumerator.nextObject() as? URL` to avoid "makeIterator" errors in Swift 6.
- **Redundant Try:** Functions in `ScannerService` are optimized; avoid adding `try await` where `Task.detached` handles the threading.

### 2. State Management & Equatable
- **ExecutionState:** Located in `ExecutionViewModel.swift`. Implement `Equatable` manually for any state with associated values to ensure stable UI comparisons.
- **Matching Model:** `ScanTarget` uses `matchingPresetId: String?`. DO NOT use the full `Preset` object in the target model to prevent reference cycles and simplify serialization.

### 3. Window & UI Management
- **Window Styles:** Uses `.unifiedCompact` toolbar and `.titleBar` window styles for a native look. Minimum window size is 900x600.
- **SF Symbols:** Always prioritize compatibility (e.g., use `list.bullet.indent` instead of `list.bullet.rectangle.stack` for better macOS version support).

### 4. Safety & Guardrails
- **.git Boundary:** The scanner NEVER treats a `.git` root as a cleanup target.
- **Trash Fallback:** If a `NativeCommandExecutor` fails, transition to `.awaitingTrashConsent` to prompt the user. NEVER move items to Trash silently.

## 🚀 How to Build & Package
1. Open `Package.swift` in Xcode.
2. Select **My Mac** as the destination.
3. Build/Run with `Cmd + R`.
4. To create a release DMG, run: `bash scripts/package.sh`.

## 📂 Key Files Map
- `DevReclaim/Core/Engine/`: The brain (Scanner, Executor).
- `DevReclaim/UI/ViewModels/`: Logic for views.
- `DevReclaim/UI/Views/Common/`: Reusable premium UI components (Cards, Badges, Banners).
- `DevReclaim/UI/MainSplitView.swift`: The main layout orchestrator.
- `DevReclaim/Models/`: Domain models (Preset, ScanTarget, ExecutionReport).
- `_bmad-output/planning-artifacts/`: Requirements & Specs.
