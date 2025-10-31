import Combine
import SwiftUI

struct InboxCarouselView: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var viewModel: InboxCarouselViewModel
  @State private var showingEditor = false
  @State private var showingMandatorySheet = false
  @State private var pendingMandatoryTaskID: String?
  @State private var pendingMandatoryPriority: TaskPriority?
  @State private var pendingMandatoryTimeslot: TaskTimeslot?
  @State private var showingSyncError = false
  @State private var syncErrorMessage = ""
  @State private var pendingErrorMessage: String?
  @GestureState private var horizontalOffset: CGFloat = 0

  init(viewModel: InboxCarouselViewModel) {
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    ZStack {
      if let task = viewModel.currentTask {
        card(for: task)
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing).combined(with: .opacity),
              removal: .move(edge: .leading).combined(with: .opacity)
            ))
      } else {
        ContentUnavailableView(
          "Inboxは空です",
          systemImage: "tray",
          description: Text("新しいタスクがNotionへ追加されるとここに表示されます。"))
      }
    }
    .background(Color(.systemBackground))
    .task {
      await viewModel.refresh()
      if !viewModel.hasTasks {
        await MainActor.run {
          dismiss()
        }
      }
    }
    .onChange(of: viewModel.hasTasks) { _, hasTasks in
      guard !hasTasks else { return }
      DispatchQueue.main.async {
        dismiss()
      }
    }
    .onReceive(viewModel.$lastError) { error in
      guard let error = error else {
        pendingErrorMessage = nil
        return
      }
      // 他のシートやアラートが表示中の場合は保留
      if showingMandatorySheet || showingEditor || showingSyncError {
        pendingErrorMessage = error
        return
      }
      // シートの transition 完了を待つため遅延
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        guard !showingMandatorySheet, !showingEditor, !showingSyncError else {
          pendingErrorMessage = error
          return
        }
        syncErrorMessage = error
        showingSyncError = true
      }
    }
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("閉じる") { dismiss() }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button {
          Task { await viewModel.refresh() }
        } label: {
          Image(systemName: "arrow.clockwise")
        }
      }
    }
    .alert("同期エラー", isPresented: $showingSyncError) {
      Button("閉じる", role: .cancel) {
        showingSyncError = false
        DispatchQueue.main.async {
          viewModel.lastError = nil
        }
      }
    } message: {
      Text(syncErrorMessage)
    }
    .sheet(
      isPresented: $showingEditor,
      onDismiss: {
        // シートが閉じた後、保留中のエラーがあれば表示
        if let error = pendingErrorMessage {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            syncErrorMessage = error
            showingSyncError = true
            pendingErrorMessage = nil
          }
        }
      }
    ) {
      if let task = viewModel.currentTask {
        TaskDetailEditor(task: task) { changes in
          Task { await viewModel.applyEdits(changes) }
        }
      }
    }
    .sheet(
      isPresented: $showingMandatorySheet,
      onDismiss: {
        // シートが閉じた後、保留中のエラーがあれば表示
        if let error = pendingErrorMessage {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            syncErrorMessage = error
            showingSyncError = true
            pendingErrorMessage = nil
          }
        }
      }
    ) {
      MandatoryFieldsSheet(
        initialPriority: pendingMandatoryPriority,
        initialTimeslot: pendingMandatoryTimeslot
      ) { priority, timeslot in
        showingMandatorySheet = false
        let pendingID = pendingMandatoryTaskID
        resetMandatoryState()
        guard let currentID = viewModel.currentTask?.id, currentID == pendingID else { return }
        Task { await viewModel.assignCurrent(priority: priority, timeslot: timeslot) }
      } onCancel: {
        showingMandatorySheet = false
        resetMandatoryState()
      }
    }
    .gesture(horizontalGesture)
    .simultaneousGesture(verticalDismissGesture)
  }

  @ViewBuilder
  private func card(for task: TaskDisplayModel) -> some View {
    InboxCardView(
      task: task,
      tint: Color.accentColor,
      onSelectPriority: { priority in
        Task { await viewModel.updatePriority(priority) }
      },
      onSelectTimeslot: { timeslot in
        Task { await viewModel.updateTimeslot(timeslot) }
      },
      onSelectTimestamp: { date in
        Task { await viewModel.updateTimestamp(to: date) }
      },
      onEdit: { showingEditor = true }
    )
    .offset(x: horizontalOffset)
    .background(background(for: horizontalOffset))
    .padding(24)
  }

  private func background(for offset: CGFloat) -> some View {
    HStack {
      if offset > 0 {
        actionLabel(text: "Triage", systemName: "tray.and.arrow.down.fill", tint: .blue)
      }
      Spacer()
      if offset < 0 {
        actionLabel(text: "Next Action", systemName: "arrow.uturn.forward", tint: .orange)
      }
    }
    .padding(.horizontal, 32)
    .opacity(abs(offset) > 5 ? 1 : 0)
  }

  private func actionLabel(text: String, systemName: String, tint: Color) -> some View {
    Label(text, systemImage: systemName)
      .font(.caption)
      .padding(8)
      .background(Capsule().fill(tint.opacity(0.8)))
      .foregroundStyle(.white)
  }

  private var horizontalGesture: some Gesture {
    DragGesture(minimumDistance: 10)
      .updating($horizontalOffset) { value, state, _ in
        guard abs(value.translation.width) > abs(value.translation.height) else { return }
        state = value.translation.width
      }
      .onEnded { value in
        guard abs(value.translation.width) > abs(value.translation.height) else { return }
        let translation = value.translation.width
        if translation > 120 {
          if let task = viewModel.currentTask,
            task.priority == nil || task.timeslot == nil
          {
            pendingMandatoryTaskID = task.id
            pendingMandatoryPriority = task.priority
            pendingMandatoryTimeslot = task.timeslot
            showingMandatorySheet = true
          } else {
            Task { await viewModel.assignCurrent() }
          }
        } else if translation < -120 {
          Task { await viewModel.convertToNextAction() }
        }
      }
  }

  private var verticalDismissGesture: some Gesture {
    DragGesture(minimumDistance: 20)
      .onEnded { value in
        let translation = value.translation
        if translation.height > 120, abs(translation.width) < 80 {
          dismiss()
        }
      }
  }
}

struct InboxCardView: View {
  let task: TaskDisplayModel
  let tint: Color
  let onSelectPriority: (TaskPriority?) -> Void
  let onSelectTimeslot: (TaskTimeslot?) -> Void
  let onSelectTimestamp: (Date?) -> Void
  let onEdit: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(alignment: .center, spacing: 12) {
        Text(task.title)
          .font(.title3.bold())
          .frame(maxWidth: .infinity, alignment: .leading)
        Button {
          onEdit()
        } label: {
          Label("編集", systemImage: "square.and.pencil")
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("詳細編集")
      }

      editorRows
      metadataRows
      memoSection
      bookmarkSection
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .shadow(radius: 20)
  }

  private var editorRows: some View {
    VStack(spacing: 12) {
      propertyEditorRow(
        title: "Priority",
        value: task.priority?.rawValue ?? "未設定",
        icon: "star",
        tintColor: tint
      ) {
        Button("未設定") { onSelectPriority(nil) }
        ForEach(TaskPriority.allCases, id: \.self) { priority in
          Button(priority.rawValue) { onSelectPriority(priority) }
        }
      }

      propertyEditorRow(
        title: "Timeslot",
        value: task.timeslot?.rawValue ?? "未設定",
        icon: "clock",
        tintColor: Color.blue
      ) {
        Button("未設定") { onSelectTimeslot(nil) }
        ForEach(TaskTimeslot.allCases, id: \.self) { slot in
          Button(slot.rawValue) { onSelectTimeslot(slot) }
        }
      }

      propertyEditorRow(
        title: "Timestamp",
        value: task.timestamp?.formatted(date: .abbreviated, time: .omitted) ?? "未設定",
        icon: "calendar",
        tintColor: Color.orange
      ) {
        Button("未設定") { onSelectTimestamp(nil) }
        Button("今日") { onSelectTimestamp(Self.todayInTokyo()) }
        Button("明日") {
          onSelectTimestamp(Self.todayInTokyo().addingTimeInterval(86_400))
        }
      }
    }
  }

  private func propertyEditorRow(
    title: String,
    value: String,
    icon: String,
    tintColor: Color,
    @ViewBuilder content: () -> some View
  ) -> some View {
    HStack {
      Text(title)
        .font(.footnote)
        .foregroundStyle(.secondary)
      Spacer()
      Menu {
        content()
      } label: {
        HStack(spacing: 6) {
          Image(systemName: icon)
          Text(value)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(tintColor.opacity(0.15), in: Capsule())
      }
      .menuStyle(.automatic)
    }
  }

  private var metadataRows: some View {
    VStack(spacing: 6) {
      propertyRow(title: "Status", value: task.status.rawValue)
      propertyRow(
        title: "Deadline",
        value: task.deadline?.formatted(date: .abbreviated, time: .omitted) ?? "未設定"
      )
      propertyRow(title: "Type", value: task.type?.rawValue ?? "未設定")
    }
    .padding(.top, 4)
  }

  private var memoSection: some View {
    Group {
      if let memo = task.memo, !memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text("Memo")
            .font(.footnote)
            .foregroundStyle(.secondary)
          Text(memo)
            .font(.body)
            .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  private var bookmarkSection: some View {
    Group {
      if let url = task.url, let label = task.bookmarkLabel {
        Link(destination: url) {
          Label(label, systemImage: "link")
            .font(.subheadline)
            .foregroundStyle(Color.white)
            .lineLimit(1)
            .truncationMode(.middle)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .accessibilityLabel("ブックマークを開く")
      }
    }
  }

  private func propertyRow(title: String, value: String) -> some View {
    HStack {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(width: 90, alignment: .leading)
      Text(value)
        .font(.body)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private static func todayInTokyo() -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .tokyo
    return calendar.startOfDay(for: Date())
  }
}

struct TaskDetailEditor: View {
  let task: TaskDisplayModel
  let onCommit: (TaskEditChanges) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var selectedStatus: TaskStatus
  @State private var selectedPriority: TaskPriority?
  @State private var selectedTimeslot: TaskTimeslot?
  @State private var selectedType: TaskType
  @State private var selectedTimestamp: Date?
  @State private var memoText: String
  @State private var titleText: String

  init(task: TaskDisplayModel, onCommit: @escaping (TaskEditChanges) -> Void) {
    self.task = task
    self.onCommit = onCommit
    _selectedStatus = State(initialValue: task.status)
    _selectedPriority = State(initialValue: task.priority)
    _selectedTimeslot = State(initialValue: task.timeslot)
    _selectedType = State(initialValue: task.type ?? .nextAction)
    _selectedTimestamp = State(initialValue: task.timestamp)
    _memoText = State(initialValue: task.memo ?? "")
    _titleText = State(initialValue: task.title)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Title") {
          TextField("タイトル", text: $titleText)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
        }

        Section("Status") {
          Picker("Status", selection: $selectedStatus) {
            ForEach(TaskStatus.allCases, id: \.self) { status in
              Text(status.rawValue).tag(status)
            }
          }
          .pickerStyle(.segmented)
        }

        Section("Priority") {
          Picker(
            "Priority",
            selection: Binding(
              get: { selectedPriority },
              set: { selectedPriority = $0 }
            )
          ) {
            Text("未設定").tag(Optional<TaskPriority>.none)
            ForEach(TaskPriority.allCases, id: \.self) { priority in
              Text(priority.rawValue).tag(Optional(priority))
            }
          }
        }

        Section("Timeslot") {
          Picker(
            "Timeslot",
            selection: Binding(
              get: { selectedTimeslot },
              set: { selectedTimeslot = $0 }
            )
          ) {
            Text("未設定").tag(Optional<TaskTimeslot>.none)
            ForEach(TaskTimeslot.allCases, id: \.self) { timeslot in
              Text(timeslot.rawValue).tag(Optional(timeslot))
            }
          }
        }

        Section("Type") {
          Picker("Type", selection: $selectedType) {
            ForEach(TaskType.allCases.filter { $0 != .trash }, id: \.self) { type in
              Text(type.rawValue).tag(type)
            }
          }
        }

        Section("Memo") {
          TextEditor(text: $memoText)
            .frame(minHeight: 120)
        }

        Section("Timestamp") {
          DatePicker(
            "日付",
            selection: Binding(
              get: {
                selectedTimestamp ?? Date()
              },
              set: { newValue in
                selectedTimestamp = newValue
              }
            ),
            displayedComponents: [.date]
          )
          .datePickerStyle(.graphical)
          Button(role: .destructive) {
            selectedTimestamp = nil
          } label: {
            Text("Timestampをクリア")
          }
          .disabled(selectedTimestamp == nil)
        }

        if let url = task.url {
          Section("Bookmark") {
            Link(destination: url) {
              Label(bookmarkLabel, systemImage: "link")
                .lineLimit(1)
                .truncationMode(.middle)
            }
          }
        }
      }
      .navigationTitle("タスクを編集")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("キャンセル") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("保存") {
            saveChanges()
            dismiss()
          }
        }
      }
    }
  }

  private func saveChanges() {
    var changes = TaskEditChanges()

    let trimmedTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
    let originalTitle = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedTitle.isEmpty, trimmedTitle != originalTitle {
      changes.name = .set(trimmedTitle)
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

    // Type の変更検出: nil の場合は必ず変更として扱う
    if let originalType = task.type {
      if selectedType != originalType {
        changes.type = .set(selectedType)
      }
    } else {
      // 元が nil なら、どの Type を選んでも変更
      changes.type = .set(selectedType)
    }

    let trimmedMemo = memoText.trimmingCharacters(in: .whitespacesAndNewlines)
    let originalMemo = (task.memo ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmedMemo != originalMemo {
      if trimmedMemo.isEmpty {
        changes.memo = .clear
      } else {
        changes.memo = .set(memoText)
      }
    }

    if selectedStatus != task.status {
      changes.status = .set(selectedStatus)
    }

    if selectedTimestamp != task.timestamp {
      if let timestamp = selectedTimestamp {
        changes.timestamp = .set(timestamp)
      } else {
        changes.timestamp = .clear
      }
    }

    if !changes.isEmpty {
      onCommit(changes)
    }
  }

  private var bookmarkLabel: String {
    task.bookmarkLabel ?? task.url?.absoluteString ?? ""
  }
}

extension InboxCarouselView {
  private func resetMandatoryState() {
    pendingMandatoryTaskID = nil
    pendingMandatoryPriority = nil
    pendingMandatoryTimeslot = nil
  }
}
