import AppKit
import SwiftUI

@main
struct DevReclaimApp: App {
    // Shared state so the main window and menubar reflect the same data.
    @State private var scannerVM = ScannerViewModel()
    @State private var executionVM = ExecutionViewModel()

    init() {
        // Ensure DevReclaim behaves as a regular macOS app and appears in Dock.
        NSApplication.shared.setActivationPolicy(.regular)

        // Ensure Dock icon is always available when running as a Swift package.
        if let image = NSImage(named: NSImage.Name("AppDockIcon")) ??
            NSImage(named: NSImage.Name("AppIcon")) {
            NSApplication.shared.applicationIconImage = image
        } else if let url = Bundle.module.url(forResource: "AppDockIcon", withExtension: "png"),
                  let image = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = image
        } else if let url = Bundle.main.url(forResource: "AppDockIcon", withExtension: "png"),
                  let image = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = image
        }
    }

    var body: some Scene {
        WindowGroup {
            MainSplitView(scannerVM: scannerVM, executionVM: executionVM)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.automatic)

        Settings {
            SettingsView(scannerVM: scannerVM)
                .frame(minWidth: 560, minHeight: 420)
        }

        MenuBarExtra("DevReclaim", systemImage: "internaldrive.fill") {
            MenuBarSummaryView(scannerVM: scannerVM)
        }
    }
}

// MARK: - Menu Bar Summary

struct MenuBarSummaryView: View {
    let scannerVM: ScannerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "internaldrive.fill")
                    .foregroundColor(.accentColor)
                Text("DevReclaim")
                    .font(.headline)
            }

            Divider()

            if scannerVM.scanTargets.isEmpty {
                Text("No scan results yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Label(
                    ByteCountFormatter.string(fromByteCount: scannerVM.totalReclaimableBytes, countStyle: .file) + " reclaimable",
                    systemImage: "leaf.fill"
                )
                .font(.subheadline)
                .foregroundColor(.green)

                Text("\(scannerVM.scanTargets.count) targets found")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if scannerVM.isScanning {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("Scanning…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            Button("Open DevReclaim") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first?.makeKeyAndOrderFront(nil)
            }

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 220)
    }
}
