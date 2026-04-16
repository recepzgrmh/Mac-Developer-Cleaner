# Project Context: DevReclaim

## Overview
**DevReclaim** is a lightweight, native macOS application designed for software developers to manage and reclaim disk space by cleaning up developer-specific artifacts (caches, build files, etc.) safely and efficiently.

## Core Principles
- **Aşırı Küçük Ayak İzi (Footprint):** No Electron, no WebViews, no heavy background processes.
- **Native-First:** Built with Swift and SwiftUI. Minimal third-party dependencies.
- **Safety First:** Uses native commands (e.g., `npm clean`) when available, falls back to Trash with explicit user consent. Never auto-deletes without guardrails (e.g., `.git` boundary check).
- **Premium UX:** Native macOS 3-pane experience following HIG, providing clear decision support and real-time feedback.

## Tech Stack
- **Language:** Swift 5.9+
- **Framework:** SwiftUI (NavigationSplitView, @Observable)
- **Engine:** Foundation (FileManager, Process, async/await)
- **Data Persistence:** Local JSON (Application Support) for Audit Logs.

## Key Modules
- **ScannerService:** Asynchronously enumerates directories, calculates allocated sizes, and identifies scan targets based on Presets.
- **ExecutionEngine:**
    - `NativeCommandExecutor`: Runs shell commands via `Process()`.
    - `TrashExecutor`: Safely moves items to the macOS Trash using `FileManager.trashItem`.
- **AuditLogger:** Records execution history to `audit-log.json` (Injectable log path for testing).
- **UI (ViewModels & Views):** Modular 3-pane architecture with specialized views for Overview, Lists, and Detail cards.

## Project Structure
- `DevReclaim/Core/`: Scanning and Execution logic.
- `DevReclaim/UI/`: Refactored ViewModels and modular SwiftUI Views (`Common/`, `ViewModels/`, `Views/`).
- `DevReclaim/Models/`: Domain models (Preset, ScanTarget, ExecutionReport).
- `DevReclaim/Tests/`: Unit tests for Scanner and Executor (Mock-aware).

## Current Status
- **Phase 1-3:** Fully implemented and refactored for Premium UI/UX.
- **Core Engine:** Verified with robust unit tests (Path standardization & Symlink aware).
- **UI:** Refactored into modular components with card-based decision support.
- **Next Steps:** Phase 4 (Distribution, DMG creation, Notarization).

## Guardrails
- **Project Boundary:** Never treats a `.git` root as a cleanup target.
- **User Consent:** Always prompts before falling back to Trash if a native command fails.
- **Risk Assessment:** Visual risk badges and confidence levels provided for every reclaimable target.
