import SwiftUI

struct SectionContainer<Content: View>: View {
    let title: String
    let subtitle: String
    let tint: Color
    let foreground: Color
    @ViewBuilder var content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(foreground)
                
                Spacer()
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color(.systemFill).opacity(0.6))
                    )
            }
            
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(tint.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(foreground.opacity(0.1), lineWidth: 0.5)
        )
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
        
        VStack(spacing: 16) {
            SectionContainer(
                title: "今日のタスク",
                subtitle: "3 tasks",
                tint: TaskPalette.todoBackground,
                foreground: TaskPalette.todoForeground
            ) {
                VStack(spacing: 8) {
                    Text("Task 1")
                    Text("Task 2")
                    Text("Task 3")
                }
            }
        }
        .padding()
    }
}
