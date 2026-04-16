import SwiftUI

struct EmptySelectionView: View {
    let title: String
    let subtitle: String
    let icon: String
    
    init(
        title: String = "No Selection",
        subtitle: String = "Please select an item from the list to see its details.",
        icon: String = "square.dashed"
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.bold())
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
