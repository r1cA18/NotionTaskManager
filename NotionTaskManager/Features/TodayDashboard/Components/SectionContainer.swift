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
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(foreground)
                
                Spacer()
                
                Text(subtitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(.systemFill))
                    )
            }
            
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(tint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(foreground.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
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
        
        SectionContainer(
            title: "完了",
            subtitle: "2 done",
            tint: TaskPalette.completedBackground,
            foreground: TaskPalette.completedForeground
        ) {
            VStack(spacing: 8) {
                Text("Completed Task 1")
                Text("Completed Task 2")
            }
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
