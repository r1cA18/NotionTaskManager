import SwiftUI

enum TaskPalette {
    // MARK: - Legacy Colors (for compatibility)
    static let todoBackground = Color.blue.opacity(0.08)
    static let todoForeground = Color.blue
    static let completedBackground = Color.green.opacity(0.08)
    static let completedForeground = Color.green
    
    // MARK: - Liquid Glass Colors
    
    static func tint(for timeslot: TaskTimeslot?) -> Color {
        switch timeslot {
        case .morning:
            return Color.orange.opacity(0.2)
        case .forenoon:
            return Color.yellow.opacity(0.2)
        case .afternoon:
            return Color.blue.opacity(0.2)
        case .evening:
            return Color.purple.opacity(0.2)
        case .none:
            return Color.gray.opacity(0.15)
        }
    }
    
    static func accentColor(for timeslot: TaskTimeslot?) -> Color {
        switch timeslot {
        case .morning: return .orange
        case .forenoon: return .yellow
        case .afternoon: return .blue
        case .evening: return .purple
        case .none: return .gray
        }
    }
    
    static func gradient(for timeslot: TaskTimeslot?) -> LinearGradient {
        let color = accentColor(for: timeslot)
        return LinearGradient(
            colors: [color.opacity(0.2), color.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Priority Colors
    
    static func priorityColor(_ priority: TaskPriority?) -> Color {
        switch priority {
        case .fourStars: return .red
        case .threeAndHalf: return .orange
        case .twoStars: return .yellow
        case .oneStar: return .green
        case .none: return .gray
        }
    }
    
    static func priorityGradient(_ priority: TaskPriority?) -> LinearGradient {
        let color = priorityColor(priority)
        return LinearGradient(
            colors: [color, color.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Status Colors
    
    static func statusColor(_ status: TaskStatus) -> Color {
        switch status {
        case .toDo: return .blue
        case .inProgress: return .orange
        case .complete: return .green
        }
    }
    
    static func statusGradient(_ status: TaskStatus) -> LinearGradient {
        let color = statusColor(status)
        return LinearGradient(
            colors: [color, color.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
