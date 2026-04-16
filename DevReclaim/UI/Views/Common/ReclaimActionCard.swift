import SwiftUI

struct ReclaimActionCard: View {
    let target: ScanTarget
    let preset: Preset
    let executionVM: ExecutionViewModel
    let onReclaimRequested: () -> Void
    let isPreparingConfirmation: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: {
                onReclaimRequested()
            }) {
                HStack {
                    if isBusy {
                        ProgressView().controlSize(.small).padding(.trailing, 4)
                    }
                    Text(isPreparingConfirmation ? "Preparing Delete Preview…" : "Delete Permanently")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(reclaimTint)
            .controlSize(.large)
            .disabled(isBusy)
            
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
    
    private var isBusy: Bool {
        executionVM.state == .runningDelete || isPreparingConfirmation
    }
    
    private var reclaimTint: Color {
        .red
    }
    
    private var statusIcon: String {
        switch executionVM.state {
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        default: return "info.circle"
        }
    }
    
    private var statusColor: Color {
        switch executionVM.state {
        case .completed: return .green
        case .failed: return .red
        default: return .secondary
        }
    }
}
