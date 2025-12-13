import SwiftUI

struct EmptyLabel: View {
    let text: String
    var icon: String = "tray"
    
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
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
