import SwiftUI

struct EmptyLabel: View {
    let text: String
    var icon: String = "tray"
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

#Preview {
    VStack(spacing: 24) {
        EmptyLabel(text: "予定されているタスクはありません")
        
        EmptyLabel(
            text: "まだ完了したタスクはありません",
            icon: "checkmark.circle"
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
