# FILE OWNERSHIP BOARD

## State Legend
- `[ ]` AVAILABLE
- `[>]` CLAIMED
- `[~]` REVIEW
- `[x]` DONE
- `[!]` BLOCKED

## Rules
1. Kod değiştirmeden önce bu dosyayı oku.
2. Sadece `[ ] AVAILABLE` olan dosyayı al.
3. Claim etmeden önce satırı `[>] CLAIMED` yap, `owner` alanına adını yaz.
4. Claim yazdıktan sonra dosyayı **tekrar oku**. Hâlâ owner sensen devam et.
5. Sadece claim ettiğin dosyada değişiklik yap.
6. İş bitince satırı `[x]` DONE yap.
7. `project.pbxproj` ve `Package.swift` coordinator-only'dir. Dokunma.

---

## 📅 Lanes & Assignments

- **Agent A (Scanner & Core)**: Epics 1, 2, 4.9
- **Agent B (Executors & VM)**: Epic 3, 4.6, 4.7
- **Agent C (App Shell & UI)**: Epics 4.1-4.5, 4.8

---

## 📁 Files (Sorted by Wave)

| state | owner | file path | updated_at | note |
|---|---|---|---|---|
| [x] | gemini | Models/DomainModels.swift | 2026-04-16 10:15 | completed Wave 0 |
| [x] | gemini | Core/Engine/ScannerService.swift | 2026-04-16 18:05 | Wave 1 Refined (Async/Try fix) |
| [x] | gemini | Core/Engine/PresetLoader.swift | 2026-04-16 11:20 | completed Wave 1 (S1.2) |
| [x] | gemini | Core/Executors/NativeCommandExecutor.swift | 2026-04-16 18:00 | Wave 1 (S3.1) |
| [x] | gemini | Core/Engine/AuditLogger.swift | 2026-04-16 18:10 | Wave 1 (DI for testing added) |
| [x] | gemini | App/DevReclaimApp.swift | 2026-04-16 18:00 | Wave 1 (Premium Window Style) |
| [x] | gemini | UI/MainSplitView.swift | 2026-04-16 18:00 | Wave 1 (Refactored to Modular) |
| [x] | gemini | Tests/ScannerTests.swift | 2026-04-16 18:11 | Wave 2 (Symlink & Module fixes) |
| [x] | gemini | UI/Views/Common/InfoBox.swift | 2026-04-16 18:00 | Wave 2 (Refined UI) |
| [x] | gemini | Core/Executors/TrashExecutor.swift | 2026-04-16 18:00 | Wave 2 (S3.2) |
| [x] | gemini | UI/ViewModels/ExecutionViewModel.swift | 2026-04-16 18:00 | Wave 2 (New ExecutionStates) |
| [x] | gemini | Tests/ExecutorTests.swift | 2026-04-16 18:11 | Wave 2 (Audit DI fix) |
| [x] | gemini | UI/Views/SidebarView.swift | 2026-04-16 18:00 | Wave 2 (Categorized sections) |
| [x] | gemini | UI/ViewModels/ScannerViewModel.swift | 2026-04-16 18:00 | Wave 2 (New metrics & phases) |
| [x] | gemini | UI/Views/HistoryView.swift | 2026-04-16 18:00 | Wave 3 (Native Table View) |
| [x] | gemini | UI/Views/Common/OverviewDashboardView.swift | 2026-04-16 18:00 | New Dashboard |
| [x] | gemini | UI/Views/Common/PresetRowView.swift | 2026-04-16 18:00 | New Modular Row View |
| [x] | gemini | UI/Views/Common/RiskBadge.swift | 2026-04-16 18:05 | Extracted Global Component |
| [x] | gemini | UI/Views/Common/EmptySelectionView.swift | 2026-04-16 18:05 | New Empty State View |
| [x] | gemini | UI/Views/Common/ReclaimActionCard.swift | 2026-04-16 18:05 | Modular Action UI |

---

## 🔒 Reserved & Coordinator Files

| state | owner | file path | updated_at | note |
|---|---|---|---|---|
| [>] | coordinator | DevReclaim.xcodeproj/project.pbxproj | - | Locked |
| [x] | gemini | Package.swift | 2026-04-16 18:10 | Refined targets |
| [>] | coordinator | DevReclaim/coordination/FILE_OWNERSHIP.md | 2026-04-16 18:15 | Sync with current code |
| [>] | coordinator | DevReclaim/coordination/AGENT_PROTOCOL.md | - | Process Guardrail |
