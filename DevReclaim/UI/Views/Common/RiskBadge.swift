import SwiftUI

struct RiskBadge: View {
    let level: RiskLevel
    
    var color: Color {
        switch level {
        case .safe: return .green
        case .usuallySafe: return .blue
        case .reviewFirst: return .orange
        case .neverAuto: return .red
        }
    }
    
    var displayText: String {
        switch level {
        case .safe:        return "Safe"
        case .usuallySafe: return "Usually Safe"
        case .reviewFirst: return "Review First"
        case .neverAuto:   return "Never Auto"
        }
    }

    var body: some View {
        Text(displayText)
            .font(.caption2).bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
    }
}
