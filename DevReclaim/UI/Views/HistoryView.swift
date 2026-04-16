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
                        HStack {
                            Image(systemName: report.wasSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(report.wasSuccess ? .green : .red)
                            Text(report.presetId)
                                .font(.headline)
                        }
                    }
                    
                    TableColumn("Method") { report in
                        Label(report.executionMode.rawValue.capitalized, 
                              systemImage: report.executionMode == .native ? "terminal" : "trash")
                            .font(.subheadline)
                    }
                    
                    TableColumn("Recovered") { report in
                        Text(ByteCountFormatter.string(fromByteCount: report.recoveredBytes, countStyle: .file))
                            .font(.system(.subheadline, design: .monospaced))
                    }
                    
                    TableColumn("Timestamp") { report in
                        Text(report.timestamp, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("History")
        .task {
            await vm.fetchHistory()
        }
    }
}
