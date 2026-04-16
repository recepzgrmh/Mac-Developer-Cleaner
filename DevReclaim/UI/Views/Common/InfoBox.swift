import SwiftUI

enum InfoBoxSeverity {
    case info
    case success
    case warning
    case error
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }
}

/// A reusable information box for displaying tips, warnings, or educational content.
struct InfoBox: View {
    let title: String
    let message: String
    let severity: InfoBoxSeverity
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        title: String,
        message: String,
        severity: InfoBoxSeverity = .info,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.severity = severity
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: severity.icon)
                .font(.title2)
                .foregroundColor(severity.color)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let actionTitle = actionTitle, let action = action {
                    Button(action: action) {
                        Text(actionTitle)
                            .font(.subheadline.bold())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(severity.color)
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(severity.color.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(severity.color.opacity(0.15), lineWidth: 1)
        )
    }
}
