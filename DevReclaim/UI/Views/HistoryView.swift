import SwiftUI

struct HistoryView: View {
    @State private var vm = HistoryViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            if vm.isFetching {
                ProgressView("Fetching history...")
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
                            Text(report.presetId)
                                .font(.subheadline)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }

                    TableColumn("Method") { report in
                        Label(
                            report.executionMode == .native ? "Native" : "Trash",
                            systemImage: report.executionMode == .native ? "terminal" : "trash"
                        )
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
}
