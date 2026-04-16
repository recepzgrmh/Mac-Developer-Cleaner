import SwiftUI

struct PermissionBannerView: View {
    let message: String
    let actionTitle: String
    let action: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "lock.shield.fill")
                .font(.title3)
                .foregroundColor(.orange)
            
            Text(message)
                .font(.subheadline)
            
            Spacer()
            
            Button(action: action) {
                Text(actionTitle)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
}
