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
    
    var body: some View {
        Text(level.rawValue.capitalized)
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
