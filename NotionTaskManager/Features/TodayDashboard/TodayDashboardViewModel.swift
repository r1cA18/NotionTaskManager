import Combine
import Foundation
import SwiftUI

@MainActor
final class TodayDashboardViewModel: ObservableObject {
  @Published var todoToday: [TaskDisplayModel] = []
  @Published var completedToday: [TaskDisplayModel] = []
  @Published var inProgress: [TaskDisplayModel] = []
  @Published var inboxTasks: [TaskDisplayModel] = []
  @Published var overdueTasks: [TaskDisplayModel] = []
  @Published var lastError: String?
  @Published var isLoading: Bool = false

  private let repository: TaskRepositoryProtocol
  private let syncService: TaskSyncService?
  private var cancellables: Set<AnyCancellable> = []
  private var currentDate: Date = Date()

  init(repository: TaskRepositoryProtocol, syncService: TaskSyncService? = nil) {
    self.repository = repository
    self.syncService = syncService
    if let syncService {
      syncService.$lastError
        .receive(on: RunLoop.main)
        .sink { [weak self] error in
          guard let self else { return }
          self.lastError = error
          if error != nil {
            Task { await self.refresh(for: self.currentDate, mode: .cacheOnly) }
          }
        }
        .store(in: &cancellables)
    }
  }

  enum RefreshMode {
    case full
    case cacheOnly
  }

  func refresh(for date: Date, mode: RefreshMode = .full) async {
    currentDate = date

    let shouldToggleLoading = mode == .full
    if shouldToggleLoading {
      guard !isLoading else {
        #if DEBUG
          print("[TodayDashboard] ⚠️ Already loading, skipping refresh")
        #endif
        return
      }
      isLoading = true
    }
    defer {
      if shouldToggleLoading {
        isLoading = false
      }
    }

    var serviceError: String?
    if mode == .full, let syncService {
      await syncService.refresh(for: date)
      serviceError = syncService.lastError
    }

    do {
      todoToday = try repository.fetchTasks(for: .todayTodo, on: date).map(TaskDisplayModel.init)
      completedToday = try repository.fetchTasks(for: .todayCompleted, on: date).map(
        TaskDisplayModel.init)
      inProgress = try repository.fetchTasks(for: .inProgress, on: date).map(TaskDisplayModel.init)
      inboxTasks = try repository.fetchTasks(for: .inbox, on: date).map(TaskDisplayModel.init)
      overdueTasks = try repository.fetchTasks(for: .overdue, on: date).map(TaskDisplayModel.init)
      #if DEBUG
        print(
          "[TodayDashboard] 📦 Todo: \(todoToday.count), ✅ Completed: \(completedToday.count), ⚡️ InProgress: \(inProgress.count), 📬 Inbox: \(inboxTasks.count), ⏰ Overdue: \(overdueTasks.count)"
        )
      #endif
      if let serviceError, mode == .full {
        lastError = serviceError
      }
    } catch {
      lastError = error.localizedDescription
      #if DEBUG
        print("[TodayDashboard] ❌ Fetch error: \(error)")
      #endif
    }
  }

  private static let timeslotOrder: [TaskTimeslot?] = [
    .morning, .forenoon, .afternoon, .evening, nil,
  ]

  var hasInboxTasks: Bool { !inboxTasks.isEmpty }
  var hasOverdueTasks: Bool { !overdueTasks.isEmpty }

  var todoGroups: [(slot: TaskTimeslot?, title: String, tint: Color, tasks: [TaskDisplayModel])] {
    let grouped = Dictionary(grouping: todoToday, by: { $0.timeslot })
    return Self.timeslotOrder.compactMap { slot in
      guard let tasks = grouped[slot], !tasks.isEmpty else { return nil }
      let title = slot?.rawValue ?? "Unscheduled"
      return (slot, title, TaskPalette.tint(for: slot), tasks)
    }
  }

  func startTask(_ model: TaskDisplayModel, on date: Date) async {
    guard let syncService else { return }
    await syncService.startTask(taskID: model.id)
    await refresh(for: date, mode: .cacheOnly)
  }

  func completeTask(_ model: TaskDisplayModel, on date: Date) async {
    guard let syncService else { return }
    await syncService.completeTask(taskID: model.id)
    await refresh(for: date, mode: .cacheOnly)
  }

  func cancelTask(_ model: TaskDisplayModel, on date: Date) async {
    guard let syncService else { return }
    await syncService.cancelTask(taskID: model.id)
    await refresh(for: date, mode: .cacheOnly)
  }

  func trashTask(_ model: TaskDisplayModel, on date: Date) async {
    var changes = TaskEditChanges()
    changes.type = .set(.trash)
    await applyEdits(changes, to: model, on: date)
  }

  func applyEdits(_ changes: TaskEditChanges, to model: TaskDisplayModel, on date: Date) async {
    guard !changes.isEmpty else { return }

    if let syncService {
      await syncService.updateTask(taskID: model.id, changes: changes)
    } else {
      do {
        try repository.update(taskID: model.id) { entity in
          changes.apply(to: entity)
        }
      } catch {
        lastError = error.localizedDescription
        return
      }
    }

    await refresh(for: date, mode: .cacheOnly)
  }
}
