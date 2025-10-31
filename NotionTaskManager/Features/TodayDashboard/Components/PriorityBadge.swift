import SwiftUI

struct PriorityBadge: View {
    let priority: TaskPriority?

    var body: some View {
        if let priority {
            Text(priority.rawValue)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.15), in: Capsule())
        }
    }
}
