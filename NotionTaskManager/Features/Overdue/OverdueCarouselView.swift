import SwiftUI

struct OverdueCarouselView: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var viewModel: OverdueCarouselViewModel
  @State private var showingEditor = false
  @State private var showingMandatorySheet = false
  @State private var pendingMandatoryTaskID: String?
  @State private var pendingMandatoryPriority: TaskPriority?
  @State private var pendingMandatoryTimeslot: TaskTimeslot?
  @State private var showingSyncError = false
  @State private var syncErrorMessage = ""
  @State private var pendingErrorMessage: String?
  @GestureState private var horizontalOffset: CGFloat = 0

  init(viewModel: OverdueCarouselViewModel) {
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
          "振り直すタスクはありません",
          systemImage: "calendar.badge.exclamationmark",
          description: Text("昨日までの未完了タスクはすべて処理済みです。"))
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
      tint: Color.red,
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
        actionLabel(text: "Delete", systemName: "trash.fill", tint: .red)
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
          Task { await viewModel.trashCurrent() }
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

  private func resetMandatoryState() {
    pendingMandatoryTaskID = nil
    pendingMandatoryPriority = nil
    pendingMandatoryTimeslot = nil
  }
}
