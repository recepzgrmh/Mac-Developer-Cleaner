import SwiftUI

struct HistoryView: View {
    @State private var vm = HistoryViewModel()
    
    var body: some View {
        List {
            if vm.reports.isEmpty && !vm.isFetching {
                ContentUnavailableView("No History", systemImage: "clock", description: Text("Reclaim actions will appear here."))
            } else {
                ForEach(vm.reports) { report in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(report.presetId)
                                .font(.headline)
                            Spacer()
                            Text("\(report.recoveredBytes / 1_000_000) MB")
                                .font(.title3)
                                .bold()
                        }
                        
                        HStack {
                            Label(report.executionMode.rawValue.capitalized, 
                                  systemImage: report.executionMode == .native ? "terminal" : "trash")
                            
                            Spacer()
                            
                            Text(report.timestamp, style: .date)
                            Text(report.timestamp, style: .time)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        if !report.wasSuccess, let error = report.errorMessage {
                            Text(error)
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("History")
        .task {
            await vm.fetchHistory()
        }
    }
}
