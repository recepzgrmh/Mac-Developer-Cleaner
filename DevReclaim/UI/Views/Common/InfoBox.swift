import SwiftUI

/// A reusable information box for displaying tips, warnings, or educational content.
struct InfoBox: View {
    let title: String
    let message: String
    let icon: String
    let color: Color
    
    init(
        title: String,
        message: String,
        icon: String = "info.circle",
        color: Color = .blue
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.color = color
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        InfoBox(
            title: "Full Disk Access",
            message: "DevReclaim works without Full Disk Access by scanning common developer paths. You can grant FDA in System Settings for a deeper scan.",
            icon: "lock.shield",
            color: .blue
        )
        
        InfoBox(
            title: "Safe to Reclaim",
            message: "These files are caches and can be safely deleted. They will be recreated automatically when needed.",
            icon: "checkmark.shield",
            color: .green
        )
        
        InfoBox(
            title: "Review Required",
            message: "Deleting these files might slow down your next build or require a fresh 'npm install'.",
            icon: "exclamationmark.triangle",
            color: .orange
        )
    }
    .padding()
    .frame(width: 400)
}
