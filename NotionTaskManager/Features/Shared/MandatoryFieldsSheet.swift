import SwiftUI

struct MandatoryFieldsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPriority: TaskPriority
    @State private var selectedTimeslot: TaskTimeslot

    let onSave: (TaskPriority, TaskTimeslot) -> Void
    let onCancel: () -> Void

    init(
        initialPriority: TaskPriority?,
        initialTimeslot: TaskTimeslot?,
        onSave: @escaping (TaskPriority, TaskTimeslot) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onSave = onSave
        self.onCancel = onCancel
        // Default to first option if not set
        _selectedPriority = State(initialValue: initialPriority ?? .twoStars)
        _selectedTimeslot = State(initialValue: initialTimeslot ?? .morning)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.accentColor)
                    Text("必須項目を設定")
                        .font(.title3.bold())
                    Text("タスクを振り分けるには、優先度と時間帯の設定が必要です")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                VStack(spacing: 20) {
                    // Priority Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Priority", systemImage: "star.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(TaskPriority.allCases) { priority in
                                PriorityOptionButton(
                                    priority: priority,
                                    isSelected: selectedPriority == priority
                                ) {
                                    withAnimation(.spring(response: 0.25)) {
                                        selectedPriority = priority
                                    }
                                }
                            }
                        }
                    }

                    Divider()

                    // Timeslot Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Timeslot", systemImage: "clock.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(TaskTimeslot.allCases) { timeslot in
                                TimeslotOptionButton(
                                    timeslot: timeslot,
                                    isSelected: selectedTimeslot == timeslot
                                ) {
                                    withAnimation(.spring(response: 0.25)) {
                                        selectedTimeslot = timeslot
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                        onSave(selectedPriority, selectedTimeslot)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Priority Option Button

private struct PriorityOptionButton: View {
    let priority: TaskPriority
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(priority.rawValue)
                .font(.system(size: 15, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? TaskPalette.priorityColor(priority).opacity(0.15) : Color(.systemFill))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? TaskPalette.priorityColor(priority) : .clear, lineWidth: 2)
                )
                .foregroundStyle(isSelected ? TaskPalette.priorityColor(priority) : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Timeslot Option Button

private struct TimeslotOptionButton: View {
    let timeslot: TaskTimeslot
    let isSelected: Bool
    let action: () -> Void

    private var icon: String {
        switch timeslot {
        case .morning: return "sunrise.fill"
        case .forenoon: return "sun.min.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(timeslot.rawValue)
                    .font(.system(size: 14, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? TaskPalette.accentColor(for: timeslot).opacity(0.15) : Color(.systemFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? TaskPalette.accentColor(for: timeslot) : .clear, lineWidth: 2)
            )
            .foregroundStyle(isSelected ? TaskPalette.accentColor(for: timeslot) : .primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MandatoryFieldsSheet(
        initialPriority: nil,
        initialTimeslot: nil,
        onSave: { _, _ in },
        onCancel: {}
    )
}
