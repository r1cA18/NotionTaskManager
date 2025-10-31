import SwiftUI

/// Main view for date-based task navigation
struct DateNavigationView: View {
  private let repository: TaskRepositoryProtocol
  private let syncService: TaskSyncService?
  @StateObject private var viewModel: DateNavigationViewModel
  @State private var showingCalendar = false
  @State private var showingInbox = false
  @State private var showingOverdue = false
  @State private var showingSyncError = false
  @State private var syncErrorMessage = ""
  @State private var activeTab: TaskTab = .todo
  @State private var editingTask: TaskDisplayModel?

  init(repository: TaskRepositoryProtocol, syncService: TaskSyncService? = nil) {
    self.repository = repository
    self.syncService = syncService
    _viewModel = StateObject(
      wrappedValue: DateNavigationViewModel(
        repository: repository,
        syncService: syncService
      )
    )
  }

  var body: some View {
    VStack(spacing: 0) {
      // Date Header (tappable to open calendar)
      DateHeaderView(
        date: viewModel.selectedDate,
        onTap: {
          showingCalendar = true
        },
        onLongPress: {
          // 長押しでTodayに遷移
          let today = Date.todayInJST()
          Task { await viewModel.selectDate(today) }
        }
      )

      // Horizontal Date Selector
      DateSelectorView(
        selectedDate: $viewModel.selectedDate,
        onDateChanged: { date in
          Task { await viewModel.selectDate(date) }
        }
      )

      // Main View with Neumorphism
      VStack(spacing: 0) {
        // Todo/Completed Tabs
        Picker("表示", selection: $activeTab) {
          ForEach(TaskTab.allCases) { tab in
            Text(tab.title).tag(tab)
          }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        .padding(.top, 16)

        // Task List
        TabView(selection: $activeTab) {
          todoPage
            .tag(TaskTab.todo)
          completedPage
            .tag(TaskTab.completed)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
      }
      .background(
        RoundedRectangle(cornerRadius: 24)
          .fill(Color(.secondarySystemGroupedBackground))
          .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: -4)
          .shadow(color: Color.white.opacity(0.5), radius: 8, x: 0, y: 4)
      )
      .clipShape(RoundedRectangle(cornerRadius: 24))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Color(.systemGroupedBackground))
    .task {
      await viewModel.selectDate(viewModel.selectedDate)
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
    .sheet(isPresented: $showingCalendar) {
      CalendarPopupView(
        selectedDate: $viewModel.selectedDate,
        onDateSelected: { date in
          Task { await viewModel.selectDate(date) }
        }
      )
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
        Task { await viewModel.applyEdits(changes, to: task) }
      }
    }
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        if viewModel.isLoading {
          ProgressView().progressViewStyle(.circular)
        } else {
          Button {
            Task { await viewModel.refreshTasks() }
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

  // MARK: - Sub Views

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
      await viewModel.refreshTasks()
    }
  }

  private var todoSection: some View {
    SectionContainer(
      title: "今日のタスク",
      subtitle: "Status = To Do",
      tint: TaskPalette.todoBackground,
      foreground: TaskPalette.todoForeground
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
                      Task { await viewModel.startTask(model) }
                    },
                    onTrash: {
                      Task { await viewModel.trashTask(model) }
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

  private var completedSection: some View {
    SectionContainer(
      title: "完了したタスク",
      subtitle: "最新順",
      tint: TaskPalette.completedBackground,
      foreground: TaskPalette.completedForeground
    ) {
      if viewModel.completedTasks.isEmpty {
        EmptyLabel(text: "まだ完了したタスクはありません")
      } else {
        VStack(spacing: 12) {
          ForEach(viewModel.completedTasks) { model in
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
    if viewModel.inProgressTasks.isEmpty {
      EmptyView()
    } else {
      VStack(spacing: 12) {
        ForEach(viewModel.inProgressTasks) { model in
          SwipeableInProgressRow(
            model: model,
            onComplete: {
              Task { await viewModel.completeTask(model) }
            },
            onCancel: {
              Task { await viewModel.cancelTask(model) }
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
}

private enum TaskTab: Int, CaseIterable, Identifiable {
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

#Preview {
  DateNavigationView(repository: PreviewTaskRepository(), syncService: nil)
}

private final class PreviewTaskRepository: TaskRepositoryProtocol {
  private var storage: [String: TaskEntity] = [:]

  func fetchTasks(for scope: TaskScope, on date: Date) throws -> [TaskEntity] {
    let tasks: [TaskEntity]
    switch scope {
    case .todayTodo:
      tasks = [
        sampleTask(
          id: "A", title: "Sample Task", status: .toDo, baseDate: date,
          timestampOffset: 0, endOffset: nil, priority: .fourStars,
          timeslot: .morning, noteType: nil)
      ]
    case .todayCompleted:
      tasks = [
        sampleTask(
          id: "B", title: "Finished Task", status: .complete, baseDate: date,
          timestampOffset: 0, endOffset: 600, priority: .threeAndHalf,
          timeslot: .evening, noteType: nil)
      ]
    case .inProgress:
      tasks = [
        sampleTask(
          id: "C", title: "In Progress", status: .inProgress, baseDate: date,
          timestampOffset: 0, endOffset: nil, priority: .twoStars,
          timeslot: .afternoon, startOffset: -300, noteType: nil)
      ]
    case .inbox:
      tasks = []
    case .overdue:
      tasks = []
    }
    tasks.forEach { storage[$0.notionID] = $0 }
    return tasks
  }

  func upsert(snapshots: [TaskSnapshot]) throws {}
  func startTask(_ task: TaskEntity, startedAt: Date) throws {}
  func completeTask(_ task: TaskEntity, completedAt: Date) throws {}
  func cancelTask(_ task: TaskEntity) throws {}
  func update(taskID: String, apply changes: (TaskEntity) -> Void) throws {}
  func remove(taskID: String) throws {}
  func task(withID id: String) throws -> TaskEntity? { storage[id] }
  func pruneTasks(matching predicate: @escaping (TaskEntity) -> Bool, keepingIDs ids: Set<String>)
    throws
  {}
  func snapshot(taskID: String) throws -> TaskSnapshot? { nil }
  func overwrite(taskID: String, with snapshot: TaskSnapshot) throws {}

  private func sampleTask(
    id: String, title: String, status: TaskStatus, baseDate: Date,
    timestampOffset: TimeInterval, endOffset: TimeInterval?,
    priority: TaskPriority?, timeslot: TaskTimeslot? = nil,
    startOffset: TimeInterval? = nil, noteType: String? = nil,
    deadlineOffset: TimeInterval? = nil
  ) -> TaskEntity {
    TaskEntity(
      notionID: id, name: title, status: status,
      timestamp: baseDate.addingTimeInterval(timestampOffset),
      timeslot: timeslot,
      endTime: endOffset.map { baseDate.addingTimeInterval($0) },
      startTime: startOffset.map { baseDate.addingTimeInterval($0) },
      priority: priority, projectIDs: [], type: nil, noteType: noteType,
      articleGenres: [], permanentTags: [],
      deadline: deadlineOffset.map { baseDate.addingTimeInterval($0) },
      spaceName: nil, url: nil, bookmarkURL: nil,
      updatedAt: .now, createdAt: .now
    )
  }
}
