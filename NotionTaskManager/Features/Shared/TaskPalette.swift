import SwiftUI

enum TaskPalette {
    static let todoBackground = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255, opacity: 0.08)
    static let todoForeground = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255)
    static let completedBackground = Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255, opacity: 0.08)
    static let completedForeground = Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255)

    static func tint(for timeslot: TaskTimeslot?) -> Color {
        switch timeslot {
        case .morning:
            return Color(red: 250 / 255, green: 224 / 255, blue: 94 / 255, opacity: 0.25)
        case .forenoon:
            return Color(red: 96 / 255, green: 165 / 255, blue: 250 / 255, opacity: 0.18)
        case .afternoon:
            return Color(red: 129 / 255, green: 199 / 255, blue: 132 / 255, opacity: 0.18)
        case .evening:
            return Color(red: 244 / 255, green: 114 / 255, blue: 182 / 255, opacity: 0.18)
        case .none:
            return Color(.secondarySystemBackground)
        }
    }
}
