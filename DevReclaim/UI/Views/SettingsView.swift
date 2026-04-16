import SwiftUI

struct SettingsView: View {
    let scannerVM: ScannerViewModel

    private enum ScanMode: String, CaseIterable, Identifiable {
        case balanced
        case comprehensive

        var id: String { rawValue }

        var title: String {
            switch self {
            case .balanced: return "Balanced"
            case .comprehensive: return "Comprehensive"
            }
        }

        var subtitle: String {
            switch self {
            case .balanced:
                return "Scans common developer paths for faster results."
            case .comprehensive:
                return "Also scans your Home folder for more project artifacts."
            }
        }

        var icon: String {
            switch self {
            case .balanced: return "speedometer"
            case .comprehensive: return "tray.full"
            }
        }
    }

    private var scanMode: Binding<ScanMode> {
        Binding(
            get: {
                scannerVM.fullHomeProjectScanEnabled ? .comprehensive : .balanced
            },
            set: { newValue in
                scannerVM.fullHomeProjectScanEnabled = (newValue == .comprehensive)
            }
        )
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Project Artifact Discovery", systemImage: "folder.badge.gearshape")
                        .font(.headline)

                    Text("Choose how broadly DevReclaim searches for build artifacts and developer caches.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Picker("Scan Mode", selection: scanMode) {
                        ForEach(ScanMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    currentModeSummary
                }
                .padding(.vertical, 4)
            }

            Section {
                settingsRow(
                    title: "Coverage",
                    value: scannerVM.fullHomeProjectScanEnabled
                        ? "Common paths + Home folder"
                        : "Common developer paths only",
                    systemImage: "scope"
                )

                settingsRow(
                    title: "Speed",
                    value: scannerVM.fullHomeProjectScanEnabled
                        ? "Slower, deeper scan"
                        : "Faster scan",
                    systemImage: "bolt"
                )

                settingsRow(
                    title: "Best for",
                    value: scannerVM.fullHomeProjectScanEnabled
                        ? "Recovering the most space"
                        : "Quick regular cleanup",
                    systemImage: "sparkles"
                )
            } header: {
                Text("What changes")
            } footer: {
                Text("Comprehensive mode may find more reclaimable files such as node_modules, build, target, and .dart_tool folders inside your Home directory.")
            }

            Section {
                Button {
                    Task { await scannerVM.scanAll() }
                } label: {
                    HStack {
                        if scannerVM.isScanning {
                            ProgressView()
                                .controlSize(.small)
                            Text("Scanning…")
                        } else {
                            Label("Run Fresh Scan", systemImage: "arrow.clockwise")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .disabled(scannerVM.isScanning)

                Text("Changes apply to the next scan. Run a fresh scan now to update results immediately.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Actions")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }

    @ViewBuilder
    private var currentModeSummary: some View {
        let mode = scanMode.wrappedValue

        HStack(alignment: .top, spacing: 12) {
            Image(systemName: mode.icon)
                .font(.title3)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(mode.title)
                    .font(.subheadline.weight(.semibold))

                Text(mode.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func settingsRow(
        title: String,
        value: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(title)

            Spacer()

            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
