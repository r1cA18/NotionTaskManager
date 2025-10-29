import Combine
import SwiftUI

struct TodayDashboardView: View {
  private let repository: TaskRepositoryProtocol
  private let syncService: TaskSyncService?
  @StateObject private var viewModel: TodayDashboardViewModel
  @State private var targetDate: Date = Date()
  @State private var showingInbox = false
  @State private var showingOverdue = false
  @State private var showingSyncError = false
  @State private var syncErrorMessage = ""
  @State private var activeTab: TodayTab = .todo
  @State private var editingTask: TaskDisplayModel?

  init(repository: TaskRepositoryProtocol, syncService: TaskSyncService? = nil) {
    self.repository = repository
    self.syncService = syncService
    _viewModel = StateObject(
      wrappedValue: TodayDashboardViewModel(repository: repository, syncService: syncService))
  }

  var body: some View {
    VStack(spacing: 16) {
      Picker("表示", selection: $activeTab) {
        ForEach(TodayTab.allCases) { tab in
          Text(tab.title).tag(tab)
        }
      }
      .pickerStyle(.segmented)
      .padding(.top, 16)
      .padding(.horizontal, 20)

      TabView(selection: $activeTab) {
        todoPage
          .tag(TodayTab.todo)
        completedPage
          .tag(TodayTab.completed)
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Color(.systemGroupedBackground))
    .task(id: targetDate) {
      await viewModel.refresh(for: targetDate)
    }
    .overlay(alignment: .bottom) {
      inProgressPill
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }
    .overlay(alignment: .bottomTrailing) {
      VStack(spacing: 16) {
        if viewModel.hasOverdueTasks {
          floatingButton(
            systemImage: "clock.arrow.circlepath",
            color: .red,
            accessibilityLabel: "Overdueを開く"
          ) { showingOverdue = true }
        }
        if viewModel.hasInboxTasks {
          floatingButton(
            systemImage: "tray.full",
            color: .accentColor,
            accessibilityLabel: "Inboxを開く"
          ) { showingInbox = true }
        }
      }
      .padding(24)
    }
    .sheet(isPresented: $showingInbox) {
      if let syncService {
        InboxCarouselView(
          viewModel: InboxCarouselViewModel(
            repository: repository,
            syncService: syncService,
            initialTasks: viewModel.inboxTasks
          )
        )
      } else {
        Text("Inboxプレビューは無効です")
          .padding()
      }
    }
    .sheet(isPresented: $showingOverdue) {
      if let syncService {
        OverdueCarouselView(
          viewModel: OverdueCarouselViewModel(
            repository: repository,
            syncService: syncService,
            initialTasks: viewModel.overdueTasks
          )
        )
      } else {
        Text("Overdueプレビューは無効です")
          .padding()
      }
    }
    .sheet(item: $editingTask) { task in
      TaskDetailEditor(task: task) { changes in
        Task { await viewModel.applyEdits(changes, to: task, on: targetDate) }
      }
    }
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        if viewModel.isLoading {
          ProgressView().progressViewStyle(.circular)
        } else {
          Button {
            Task { await refreshToday() }
          } label: {
            Image(systemName: "arrow.clockwise")
          }
          .accessibilityLabel("Refresh tasks")
        }
      }
    }
    .onReceive(viewModel.$lastError) { error in
      DispatchQueue.main.async {
        syncErrorMessage = error ?? ""
        showingSyncError = error != nil
      }
    }
    .alert("同期エラー", isPresented: $showingSyncError) {
      Button("閉じる", role: .cancel) {
        showingSyncError = false
        Task { @MainActor in viewModel.lastError = nil }
      }
    } message: {
      Text(syncErrorMessage)
    }
  }

  private var todoPage: some View {
    buildPage {
      todoSection
    }
  }

  private var completedPage: some View {
    buildPage {
      completedSection
    }
  }

  private func buildPage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    ScrollView {
      VStack(spacing: 24) {
        content()
      }
      .padding(.horizontal, 20)
      .padding(.top, 24)
      .padding(.bottom, 180)
    }
    .refreshable {
      await refreshToday()
    }
  }

  private func refreshToday() async {
    let now = Date()
    await MainActor.run {
      targetDate = now
    }
    await viewModel.refresh(for: now)
  }

  private var todoSection: some View {
    SectionContainer(
      title: "今日のタスク",
      subtitle: "Status = To Do",
      tint: Palette.todoBackground,
      foreground: Palette.todoForeground
    ) {
      if viewModel.todoGroups.isEmpty {
        EmptyLabel(text: "予定されているタスクはありません")
      } else {
        VStack(spacing: 16) {
          ForEach(Array(viewModel.todoGroups.enumerated()), id: \.offset) { _, group in
            VStack(alignment: .leading, spacing: 12) {
              Text(group.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(group.tint.opacity(0.35), in: Capsule())
              VStack(spacing: 12) {
                ForEach(group.tasks) { model in
                  TodoCard(
                    model: model,
                    tint: group.tint,
                    onStart: {
                      Task { await viewModel.startTask(model, on: targetDate) }
                    },
                    onTrash: {
                      Task { await viewModel.trashTask(model, on: targetDate) }
                    },
                    onTap: {
                      editingTask = model
                    }
                  )
                }
              }
            }
          }
        }
      }
    }
  }

  private func floatingButton(
    systemImage: String,
    color: Color,
    accessibilityLabel: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.title2)
        .foregroundStyle(.white)
        .padding()
        .background(Circle().fill(color))
        .shadow(radius: 4)
    }
    .accessibilityLabel(accessibilityLabel)
  }

  private var completedSection: some View {
    SectionContainer(
      title: "完了したタスク",
      subtitle: "最新順",
      tint: Palette.completedBackground,
      foreground: Palette.completedForeground
    ) {
      if viewModel.completedToday.isEmpty {
        EmptyLabel(text: "まだ完了したタスクはありません")
      } else {
        VStack(spacing: 12) {
          ForEach(viewModel.completedToday) { model in
            CompletedCard(
              model: model,
              onTap: {
                editingTask = model
              }
            )
          }
        }
      }
    }
  }

  @ViewBuilder
  private var inProgressPill: some View {
    if viewModel.inProgress.isEmpty {
      EmptyView()
    } else {
      VStack(spacing: 12) {
        ForEach(viewModel.inProgress) { model in
          SwipeableInProgressRow(
            model: model,
            onComplete: {
              Task { await viewModel.completeTask(model, on: targetDate) }
            },
            onCancel: {
              Task { await viewModel.cancelTask(model, on: targetDate) }
            },
            onTap: {
              editingTask = model
            }
          )
        }
      }
      .transition(.move(edge: .bottom).combined(with: .opacity))
    }
  }
}

private enum TodayTab: Int, CaseIterable, Identifiable {
  case todo
  case completed

  var id: Int { rawValue }

  var title: String {
    switch self {
    case .todo: return "To Do"
    case .completed: return "Complete"
    }
  }
}

private struct SectionContainer<Content: View>: View {
  let title: String
  let subtitle: String
  let tint: Color
  let foreground: Color
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 8) {
        Text(title)
          .font(.headline)
          .foregroundStyle(foreground)
        Spacer()
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      content
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

private struct EmptyLabel: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct TodoCard: View {
  let model: TaskDisplayModel
  let tint: Color
  let onStart: () -> Void
  let onTrash: () -> Void
  let onTap: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Text(model.title)
          .font(.body)
          .foregroundStyle(.primary)
        Spacer()
        PriorityBadge(priority: model.priority)
      }

      HStack(spacing: 8) {
        if let timestamp = model.timestamp {
          Label(timestamp.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
            .labelStyle(.titleAndIcon)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Label(model.timeslotLabel, systemImage: "clock")
          .labelStyle(.titleAndIcon)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      if let memo = memoText {
        Text(memo)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .lineLimit(3)
      }
      if let url = model.url, let label = model.bookmarkLabel {
        Link(destination: url) {
          Label(label, systemImage: "link")
            .font(.footnote)
            .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("関連リンクを開く")
      }

      HStack(spacing: 12) {
        Button(action: onStart) {
          Label("開始", systemImage: "play.fill")
            .font(.subheadline)
        }
        .buttonStyle(.borderedProminent)
        .tint(.accentColor)
        .disabled(model.status == .inProgress)

        Button(role: .destructive, action: onTrash) {
          Image(systemName: "trash")
            .padding(6)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("タスクを削除")
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(tint.opacity(0.6), lineWidth: 1.2)
    )
    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .onTapGesture(perform: onTap)
  }

  private var memoText: String? {
    let trimmed = model.memo?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? nil : trimmed
  }
}

private struct CompletedCard: View {
  let model: TaskDisplayModel
  let onTap: () -> Void
  let tint: Color = Palette.completedForeground

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(model.title)
        .font(.body)
        .foregroundStyle(.primary)
      if let memo = memoText {
        Text(memo)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .lineLimit(3)
      }
      if let url = model.url, let label = model.bookmarkLabel {
        Link(destination: url) {
          Label(label, systemImage: "link")
            .font(.caption)
            .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("関連リンクを開く")
      }
      if let endTime = model.endTime {
        Label(
          endTime.formatted(date: .omitted, time: .shortened), systemImage: "checkmark.seal.fill"
        )
        .labelStyle(.titleAndIcon)
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(tint.opacity(0.6), lineWidth: 1.2)
    )
    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .onTapGesture(perform: onTap)
  }

  private var memoText: String? {
    let trimmed = model.memo?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? nil : trimmed
  }
}

private struct InProgressBar: View {
  let model: TaskDisplayModel

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "bolt.fill")
        .foregroundStyle(.white)
        .frame(width: 32, height: 32)
        .background(Circle().fill(Color.accentColor))
      VStack(alignment: .leading, spacing: 4) {
        Text("In Progress")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(model.title)
          .font(.subheadline)
          .foregroundStyle(.primary)
        HStack(spacing: 8) {
          Label(model.timeslotLabel, systemImage: "clock")
            .font(.caption)
            .foregroundStyle(.secondary)
          if let startTime = model.startTime {
            Label(
              startTime.formatted(date: .omitted, time: .shortened),
              systemImage: "clock.arrow.circlepath"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
          }
        }
        if let memo = memoText {
          Text(memo)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(3)
        }
        if let url = model.url, let label = model.bookmarkLabel {
          Link(destination: url) {
            Label(label, systemImage: "link")
              .font(.caption)
              .foregroundStyle(Color.accentColor)
          }
          .buttonStyle(.borderless)
          .accessibilityLabel("関連リンクを開く")
        }
      }
      Spacer()
    }
    .padding(16)
    .frame(maxWidth: .infinity)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
      .stroke(Palette.tint(for: model.timeslot).opacity(0.6), lineWidth: 1.2)
    )
    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
  }

  private var memoText: String? {
    let trimmed = model.memo?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? nil : trimmed
  }
}

private struct PriorityBadge: View {
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

private enum Palette {
  static let todoBackground = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255, opacity: 0.08)
  static let todoForeground = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255)
  static let completedBackground = Color(
    red: 34 / 255, green: 197 / 255, blue: 94 / 255, opacity: 0.08)
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

#Preview {
  TodayDashboardView(repository: PreviewTaskRepository(), syncService: nil)
    .padding()
    .background(Color(.systemGroupedBackground))
}

private final class PreviewTaskRepository: TaskRepositoryProtocol {
  private var storage: [String: TaskEntity] = [:]

  func fetchTasks(for scope: TaskScope, on date: Date) throws -> [TaskEntity] {
    let tasks: [TaskEntity]
    switch scope {
    case .todayTodo:
      tasks = [
        sampleTask(
          id: "A", title: "Inbox Task", status: .toDo, baseDate: date, timestampOffset: 0,
          endOffset: nil, priority: .fourStars, timeslot: .morning, noteType: nil)
      ]
    case .todayCompleted:
      tasks = [
        sampleTask(
          id: "B", title: "Finished Task", status: .complete, baseDate: date, timestampOffset: 0,
          endOffset: 600, priority: .threeAndHalf, timeslot: .evening, noteType: nil)
      ]
    case .inProgress:
      tasks = [
        sampleTask(
          id: "C", title: "In Progress", status: .inProgress, baseDate: date, timestampOffset: 0,
          endOffset: nil, priority: .twoStars, timeslot: .afternoon, startOffset: -300,
          noteType: nil)
      ]
    case .inbox:
      tasks = [
        sampleTask(
          id: "D", title: "Inbox Preview", status: .toDo, baseDate: date, timestampOffset: 0,
          endOffset: nil, priority: .twoStars, timeslot: nil, noteType: nil)
      ]
    case .overdue:
      tasks = [
        sampleTask(
          id: "E", title: "Overdue Task", status: .toDo, baseDate: date.addingTimeInterval(-86_400),
          timestampOffset: -86_400, endOffset: nil, priority: .oneStar, timeslot: nil,
          noteType: nil, deadlineOffset: -86_400)
      ]
    }
    tasks.forEach { storage[$0.notionID] = $0 }
    return tasks
  }

  func upsert(snapshots: [TaskSnapshot]) throws {
    for snapshot in snapshots {
      storage[snapshot.notionID] = TaskEntity(
        notionID: snapshot.notionID,
        name: snapshot.name,
        memo: snapshot.memo,
        status: snapshot.status,
        timestamp: snapshot.timestamp,
        timeslot: snapshot.timeslot,
        endTime: snapshot.endTime,
        startTime: snapshot.startTime,
        priority: snapshot.priority,
        projectIDs: snapshot.projectIDs,
        type: snapshot.type,
        noteType: snapshot.noteType,
        articleGenres: snapshot.articleGenres,
        permanentTags: snapshot.permanentTags,
        deadline: snapshot.deadline,
        spaceName: snapshot.spaceName,
        url: snapshot.url,
        bookmarkURL: snapshot.bookmarkURL,
        updatedAt: snapshot.updatedAt,
        createdAt: snapshot.createdAt
      )
    }
  }

  func startTask(_ task: TaskEntity, startedAt: Date) throws {
    task.status = .inProgress
    task.startTime = startedAt
  }

  func completeTask(_ task: TaskEntity, completedAt: Date) throws {
    task.status = .complete
    task.endTime = completedAt
  }

  func cancelTask(_ task: TaskEntity) throws {
    task.status = .toDo
    task.startTime = nil
  }

  func update(taskID: String, apply changes: (TaskEntity) -> Void) throws {
    guard let task = storage[taskID] else { return }
    changes(task)
  }

  func remove(taskID: String) throws {
    storage.removeValue(forKey: taskID)
  }

  func task(withID id: String) throws -> TaskEntity? {
    storage[id]
  }

  func pruneTasks(matching predicate: @escaping (TaskEntity) -> Bool, keepingIDs ids: Set<String>)
    throws
  {
    storage = storage.filter { key, value in
      guard predicate(value) else { return true }
      return ids.contains(key)
    }
  }

  func snapshot(taskID: String) throws -> TaskSnapshot? {
    guard let task = storage[taskID] else { return nil }
    return TaskSnapshot(task: task)
  }

  func overwrite(taskID: String, with snapshot: TaskSnapshot) throws {
    storage[taskID] = TaskEntity(
      notionID: snapshot.notionID,
      name: snapshot.name,
      memo: snapshot.memo,
      status: snapshot.status,
      timestamp: snapshot.timestamp,
      timeslot: snapshot.timeslot,
      endTime: snapshot.endTime,
      startTime: snapshot.startTime,
      priority: snapshot.priority,
      projectIDs: snapshot.projectIDs,
      type: snapshot.type,
      noteType: snapshot.noteType,
      articleGenres: snapshot.articleGenres,
      permanentTags: snapshot.permanentTags,
      deadline: snapshot.deadline,
      spaceName: snapshot.spaceName,
      url: snapshot.url,
      bookmarkURL: snapshot.bookmarkURL,
      updatedAt: snapshot.updatedAt,
      createdAt: snapshot.createdAt
    )
  }

  private func sampleTask(
    id: String,
    title: String,
    status: TaskStatus,
    baseDate: Date,
    timestampOffset: TimeInterval,
    endOffset: TimeInterval?,
    priority: TaskPriority?,
    timeslot: TaskTimeslot? = nil,
    startOffset: TimeInterval? = nil,
    noteType: String? = nil,
    deadlineOffset: TimeInterval? = nil
  ) -> TaskEntity {
    TaskEntity(
      notionID: id,
      name: title,
      status: status,
      timestamp: baseDate.addingTimeInterval(timestampOffset),
      timeslot: timeslot,
      endTime: endOffset.map { baseDate.addingTimeInterval($0) },
      startTime: startOffset.map { baseDate.addingTimeInterval($0) },
      priority: priority,
      projectIDs: [],
      type: nil,
      noteType: noteType,
      articleGenres: [],
      permanentTags: [],
      deadline: deadlineOffset.map { baseDate.addingTimeInterval($0) },
      spaceName: nil,
      url: nil,
      bookmarkURL: nil,
      updatedAt: .now,
      createdAt: .now
    )
  }
}

private struct SwipeableInProgressRow: View {
  let model: TaskDisplayModel
  let onComplete: () -> Void
  let onCancel: () -> Void
  let onTap: () -> Void

  @GestureState private var dragOffset: CGFloat = 0
  private let threshold: CGFloat = 80

  var body: some View {
    let offset = dragOffset
    ZStack {
      HStack {
        if offset > 0 {
          actionLabel(text: "Complete", systemImage: "checkmark", color: .green)
        }
        Spacer()
        if offset < 0 {
          actionLabel(text: "Cancel", systemImage: "arrow.uturn.backward", color: .orange)
        }
      }
      .padding(.horizontal, 24)

      InProgressBar(model: model)
        .offset(x: offset)
        .gesture(
          DragGesture(minimumDistance: 10)
            .updating($dragOffset) { value, state, _ in
              state = value.translation.width
            }
            .onEnded { value in
              let width = value.translation.width
              withAnimation(.spring()) {
                if width > threshold {
                  onComplete()
                } else if width < -threshold {
                  onCancel()
                }
              }
            }
        )
        .onTapGesture(perform: onTap)
    }
  }

  private func actionLabel(text: String, systemImage: String, color: Color) -> some View {
    Label(text, systemImage: systemImage)
      .font(.caption)
      .foregroundStyle(.white)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(Capsule().fill(color))
  }
}
