import SwiftUI

struct MandatoryFieldsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPriority: TaskPriority?
    @State private var selectedTimeslot: TaskTimeslot?

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
        _selectedPriority = State(initialValue: initialPriority)
        _selectedTimeslot = State(initialValue: initialTimeslot)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Priority") {
                    Picker("Priority", selection: $selectedPriority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Text(priority.rawValue).tag(Optional(priority))
                        }
                    }
                    .pickerStyle(.wheel)
                }

                Section("Timeslot") {
                    Picker("Timeslot", selection: $selectedTimeslot) {
                        ForEach(TaskTimeslot.allCases, id: \.self) { timeslot in
                            Text(timeslot.rawValue).tag(Optional(timeslot))
                        }
                    }
                    .pickerStyle(.wheel)
                }
            }
            .navigationTitle("必須項目を入力")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        guard
                            let priority = selectedPriority,
                            let timeslot = selectedTimeslot
                        else { return }
                        dismiss()
                        onSave(priority, timeslot)
                    }
                    .disabled(selectedPriority == nil || selectedTimeslot == nil)
                }
            }
        }
        .presentationDetents([.fraction(0.4), .medium])
    }
}
