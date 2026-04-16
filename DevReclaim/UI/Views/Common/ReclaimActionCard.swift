import SwiftUI

struct ReclaimActionCard: View {
    let target: ScanTarget
    let preset: Preset
    let executionVM: ExecutionViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task { await executionVM.execute(target: target, preset: preset) }
            }) {
                HStack {
                    if isExecuting {
                        ProgressView().controlSize(.small).padding(.trailing, 4)
                    }
                    Text("Reclaim Space")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(reclaimTint)
            .controlSize(.large)
            .disabled(isExecuting)
            
            if !executionVM.userFacingStatus.isEmpty {
                HStack {
                    Image(systemName: statusIcon)
                        .foregroundColor(statusColor)
                    Text(executionVM.userFacingStatus)
                        .font(.subheadline)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 4)
            }
        }
    }
    
    private var isExecuting: Bool {
        executionVM.state == .runningNative || executionVM.state == .runningTrash
    }
    
    private var reclaimTint: Color {
        preset.riskLevel == .safe ? .accentColor : .red
    }
    
    private var statusIcon: String {
        switch executionVM.state {
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .awaitingTrashConsent: return "questionmark.circle.fill"
        default: return "info.circle"
        }
    }
    
    private var statusColor: Color {
        switch executionVM.state {
        case .completed: return .green
        case .failed: return .red
        case .awaitingTrashConsent: return .orange
        default: return .secondary
        }
    }
}
