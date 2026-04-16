import SwiftUI

struct HistoryView: View {
    @State private var vm = HistoryViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            if vm.isFetching {
                ProgressView("Fetching history...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.lastError {
                ContentUnavailableView(
                    "History Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.reports.isEmpty {
                ContentUnavailableView(
                    "No History Found",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Items will appear here after you reclaim some space.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(vm.reports) {
                    TableColumn("Preset") { report in
                        HStack(spacing: 6) {
                            Image(systemName: report.wasSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(report.wasSuccess ? .green : .red)
                                .frame(width: 16)
                            Text(vm.presetDisplayName(for: report))
                                .font(.subheadline)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }

                    TableColumn("Method") { report in
                        let method = methodDisplay(for: report.executionMode)
                        Label(method.label, systemImage: method.icon)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                    .width(min: 80, ideal: 100, max: 120)

                    TableColumn("Recovered") { report in
                        Text(ByteCountFormatter.string(fromByteCount: report.recoveredBytes, countStyle: .file))
                            .font(.system(.subheadline, design: .monospaced))
                            .lineLimit(1)
                    }
                    .width(min: 80, ideal: 100, max: 120)

                    TableColumn("Date") { report in
                        Text(report.timestamp, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .width(min: 80, ideal: 110, max: 140)
                }
            }
        }
        .navigationTitle("History")
        .task {
            await vm.fetchHistory()
        }
    }

    private func methodDisplay(for mode: ExecutionMode) -> (label: String, icon: String) {
        switch mode {
        case .native:
            return ("Native", "terminal")
        case .trash:
            return ("Trash", "trash")
        case .delete:
            return ("Delete", "trash.slash")
        }
    }
}
