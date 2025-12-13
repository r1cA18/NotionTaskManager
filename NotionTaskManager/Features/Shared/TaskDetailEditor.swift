import SwiftUI

/// A sheet for editing task details
struct TaskDetailEditor: View {
    @Environment(\.dismiss) private var dismiss
    let task: TaskDisplayModel
    let onSave: (TaskEditChanges) -> Void

    @State private var name: String
    @State private var selectedPriority: TaskPriority?
    @State private var selectedTimeslot: TaskTimeslot?
    @State private var selectedType: TaskType?
    @State private var timestamp: Date?
    @State private var deadline: Date?
    @State private var memo: String

    init(task: TaskDisplayModel, onSave: @escaping (TaskEditChanges) -> Void) {
        self.task = task
        self.onSave = onSave
        _name = State(initialValue: task.title)
        _selectedPriority = State(initialValue: task.priority)
        _selectedTimeslot = State(initialValue: task.timeslot)
        _selectedType = State(initialValue: task.type)
        _timestamp = State(initialValue: task.timestamp)
        _deadline = State(initialValue: task.deadline)
        _memo = State(initialValue: task.memo ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("タスク名") {
                    TextField("タスク名", text: $name)
                }

                Section("優先度") {
                    Picker("優先度", selection: $selectedPriority) {
                        Text("未設定").tag(nil as TaskPriority?)
                        ForEach(TaskPriority.allCases) { priority in
                            Text(priority.rawValue).tag(priority as TaskPriority?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("時間帯") {
                    Picker("時間帯", selection: $selectedTimeslot) {
                        Text("未設定").tag(nil as TaskTimeslot?)
                        ForEach(TaskTimeslot.allCases) { slot in
                            Text(slot.rawValue).tag(slot as TaskTimeslot?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("タイプ") {
                    Picker("タイプ", selection: $selectedType) {
                        Text("未設定").tag(nil as TaskType?)
                        ForEach(TaskType.allCases) { type in
                            Text(type.rawValue).tag(type as TaskType?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("日付") {
                    DatePicker(
                        "予定日",
                        selection: Binding(
                            get: { timestamp ?? Date() },
                            set: { timestamp = $0 }
                        ),
                        displayedComponents: .date
                    )

                    if timestamp != nil {
                        Button("予定日をクリア", role: .destructive) {
                            timestamp = nil
                        }
                    }
                }

                Section("締め切り") {
                    DatePicker(
                        "締め切り",
                        selection: Binding(
                            get: { deadline ?? Date() },
                            set: { deadline = $0 }
                        ),
                        displayedComponents: .date
                    )

                    if deadline != nil {
                        Button("締め切りをクリア", role: .destructive) {
                            deadline = nil
                        }
                    }
                }

                Section("メモ") {
                    TextEditor(text: $memo)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("タスクを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasChanges)
                }
            }
        }
    }

    private var hasChanges: Bool {
        name != task.title ||
        selectedPriority != task.priority ||
        selectedTimeslot != task.timeslot ||
        selectedType != task.type ||
        timestamp != task.timestamp ||
        deadline != task.deadline ||
        memo != (task.memo ?? "")
    }

    private func saveChanges() {
        var changes = TaskEditChanges()

        if name != task.title {
            changes.name = .set(name)
        }

        if selectedPriority != task.priority {
            if let priority = selectedPriority {
                changes.priority = .set(priority)
            } else {
                changes.priority = .clear
            }
        }

        if selectedTimeslot != task.timeslot {
            if let timeslot = selectedTimeslot {
                changes.timeslot = .set(timeslot)
            } else {
                changes.timeslot = .clear
            }
        }

        if selectedType != task.type {
            if let type = selectedType {
                changes.type = .set(type)
            } else {
                changes.type = .clear
            }
        }

        if timestamp != task.timestamp {
            if let ts = timestamp {
                changes.timestamp = .set(ts)
            } else {
                changes.timestamp = .clear
            }
        }

        if deadline != task.deadline {
            if let dl = deadline {
                changes.deadline = .set(dl)
            } else {
                changes.deadline = .clear
            }
        }

        if memo != (task.memo ?? "") {
            if memo.isEmpty {
                changes.memo = .clear
            } else {
                changes.memo = .set(memo)
            }
        }

        onSave(changes)
        dismiss()
    }
}
