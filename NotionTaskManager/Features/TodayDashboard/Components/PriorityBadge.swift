import SwiftUI

struct PriorityBadge: View {
    let priority: TaskPriority?
    var compact: Bool = false
    
    var body: some View {
        if let priority {
            let color = TaskPalette.priorityColor(priority)
            
            if compact {
                compactBadge(priority: priority, color: color)
            } else {
                fullBadge(priority: priority, color: color)
            }
        }
    }
    
    private func compactBadge(priority: TaskPriority, color: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill")
                .font(.system(size: 8))
            Text(shortLabel(priority))
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
    }
    
    private func fullBadge(priority: TaskPriority, color: Color) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<starCount(priority), id: \.self) { index in
                Image(systemName: isHalfStar(priority, at: index) ? "star.leadinghalf.filled" : "star.fill")
                    .font(.system(size: 10))
            }
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
    }
    
    private func shortLabel(_ priority: TaskPriority) -> String {
        switch priority {
        case .fourStars: return "4"
        case .threeAndHalf: return "3.5"
        case .twoStars: return "2"
        case .oneStar: return "1"
        }
    }
    
    private func starCount(_ priority: TaskPriority) -> Int {
        switch priority {
        case .fourStars: return 4
        case .threeAndHalf: return 4
        case .twoStars: return 2
        case .oneStar: return 1
        }
    }
    
    private func isHalfStar(_ priority: TaskPriority, at index: Int) -> Bool {
        priority == .threeAndHalf && index == 3
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            PriorityBadge(priority: .fourStars)
            PriorityBadge(priority: .threeAndHalf)
            PriorityBadge(priority: .twoStars)
            PriorityBadge(priority: .oneStar)
        }
        
        HStack(spacing: 12) {
            PriorityBadge(priority: .fourStars, compact: true)
            PriorityBadge(priority: .threeAndHalf, compact: true)
            PriorityBadge(priority: .twoStars, compact: true)
            PriorityBadge(priority: .oneStar, compact: true)
        }
    }
    .padding()
}
