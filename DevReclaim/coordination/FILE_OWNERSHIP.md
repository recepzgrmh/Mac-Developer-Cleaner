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
| [x] | gemini | Core/Engine/ScannerService.swift | 2026-04-16 11:45 | completed Wave 1 (S2.1) |
| [x] | gemini | Core/Engine/PresetLoader.swift | 2026-04-16 11:20 | completed Wave 1 (S1.2) |
| [ ] | - | Core/Executors/NativeCommandExecutor.swift | - | Wave 1 (S3.1) Agent B |
| [ ] | - | Core/Engine/AuditLogger.swift | - | Wave 1 (S3.3) Agent B |
| [ ] | - | App/DevReclaimApp.swift | - | Wave 1 (S4.1) Agent C |
| [ ] | - | UI/MainSplitView.swift | - | Wave 1 (S4.2) Agent C |
| [x] | gemini | Tests/ScannerTests.swift | 2026-04-16 11:55 | completed Wave 2 (S2.2) |
| [x] | gemini | UI/Views/Common/InfoBox.swift | 2026-04-16 12:05 | completed Wave 2 (S4.9) |
| [ ] | - | Core/Executors/TrashExecutor.swift | - | Wave 2 (S3.2) Agent B |
| [ ] | - | UI/ViewModels/ExecutionViewModel.swift | - | Wave 2 (S4.6) Agent B |
| [ ] | - | Tests/ExecutorTests.swift | - | Wave 2 (S3.4) Agent B |
| [ ] | - | UI/Views/SidebarView.swift | - | Wave 2 (S4.3) Agent C |
| [ ] | - | UI/ViewModels/ScannerViewModel.swift | - | Wave 2 (S4.4) Agent C |
| [ ] | - | UI/Views/DetailPanelView.swift | - | Wave 3 (S4.7) Agent B |
| [ ] | - | UI/Views/PresetListView.swift | - | Wave 3 (S4.5) Agent C |
| [ ] | - | UI/Views/HistoryView.swift | - | Wave 3 (S4.8) Agent C |

---

## 🔒 Reserved & Coordinator Files

| state | owner | file path | updated_at | note |
|---|---|---|---|---|
| [>] | coordinator | DevReclaim.xcodeproj/project.pbxproj | - | Locked |
| [>] | coordinator | Package.swift | - | Locked |
| [>] | coordinator | DevReclaim/coordination/FILE_OWNERSHIP.md | - | Source of Truth |
| [>] | coordinator | DevReclaim/coordination/AGENT_PROTOCOL.md | - | Process Guardrail |

---

## Claim Example

```
Before:  | [ ] | - | Models/DomainModels.swift | - | - |
Claimed: | [>] | cursor | Models/DomainModels.swift | 2026-04-16 17:02 | implementing |
Done:    | [x] | cursor | Models/DomainModels.swift | 2026-04-16 17:30 | completed |
```
