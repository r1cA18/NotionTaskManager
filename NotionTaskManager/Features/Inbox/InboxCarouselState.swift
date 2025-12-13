import Combine
import SwiftUI

@MainActor
final class InboxCarouselViewModel: ObservableObject {
  @Published private(set) var queue: [TaskDisplayModel]
  @Published var isLoading = false
  @Published var lastError: String?

  private let repository: TaskRepositoryProtocol
  private let syncService: TaskSyncService
  private var cancellables: Set<AnyCancellable> = []

  init(
    repository: TaskRepositoryProtocol, syncService: TaskSyncService,
    initialTasks: [TaskDisplayModel] = []
  ) {
    self.repository = repository
    self.syncService = syncService
    var sanitized: [TaskDisplayModel] = []
    for model in initialTasks {
      if let entity = try? repository.task(withID: model.id), entity.isInboxCandidate {
        sanitized.append(TaskDisplayModel(task: entity))
      }
    }
    self.queue = sanitized
    syncService.$lastError
      .receive(on: RunLoop.main)
      .sink { [weak self] error in
        guard let self else { return }
        self.lastError = error
        if error != nil {
          self.reloadQueueFromCache()
        }
      }
      .store(in: &cancellables)
  }

  var currentTask: TaskDisplayModel? { queue.first }
  var hasTasks: Bool { !queue.isEmpty }

  func refresh() async {
    guard !isLoading else { return }
    isLoading = true
    defer { isLoading = false }
    await syncService.refresh(for: Date())
    if let error = syncService.lastError {
      lastError = error
    }
    reloadQueueFromCache()
  }

  func applyEdits(_ changes: TaskEditChanges) async {
    guard let task = currentTask, !changes.isEmpty else { return }
    await syncService.updateTask(taskID: task.id, changes: changes)
    reloadQueueFromCache()
  }

  func updatePriority(_ priority: TaskPriority?) async {
    var changes = TaskEditChanges()
    if let priority {
      changes.priority = .set(priority)
    } else {
      changes.priority = .clear
    }
    await applyEdits(changes)
  }

  func updateTimeslot(_ timeslot: TaskTimeslot?) async {
    var changes = TaskEditChanges()
    if let timeslot {
      changes.timeslot = .set(timeslot)
    } else {
      changes.timeslot = .clear
    }
    await applyEdits(changes)
  }

  func updateTimestamp(to date: Date?) async {
    var changes = TaskEditChanges()
    if let date {
      changes.timestamp = .set(date)
    } else {
      changes.timestamp = .clear
    }
    await applyEdits(changes)
  }

  // MARK: - Triage Actions

  func assignCurrent() async {
    guard await ensureTimestampIsToday() else { return }
    await performConvertToNextAction()
  }

  func assignCurrent(priority: TaskPriority, timeslot: TaskTimeslot) async {
    await applyMandatoryFields(priority: priority, timeslot: timeslot)
    guard lastError == nil else { return }
    await performConvertToNextAction()
  }

  // MARK: - NextAction Conversion

  func convertToNextAction() async {
    guard await ensureTimestampIsToday() else { return }
    await performConvertToNextAction()
  }

  func convertToNextAction(priority: TaskPriority, timeslot: TaskTimeslot) async {
    await applyMandatoryFields(priority: priority, timeslot: timeslot)
    guard lastError == nil else { return }
    await performConvertToNextAction()
  }

  // MARK: - Private Helpers

  private func applyMandatoryFields(priority: TaskPriority, timeslot: TaskTimeslot) async {
    var changes = TaskEditChanges()
    changes.priority = .set(priority)
    changes.timeslot = .set(timeslot)
    if needsTimestampUpdate() {
      changes.timestamp = .set(.todayInJST())
    }
    await applyEdits(changes)
  }

  private func ensureTimestampIsToday() async -> Bool {
    guard needsTimestampUpdate() else { return true }
    var changes = TaskEditChanges()
    changes.timestamp = .set(.todayInJST())
    await applyEdits(changes)
    return lastError == nil
  }

  private func needsTimestampUpdate() -> Bool {
    guard let timestamp = currentTask?.timestamp else { return true }
    return timestamp < .todayInJST()
  }

  private func performConvertToNextAction() async {
    guard let task = currentTask else { return }
    await syncService.convertToNextAction(taskID: task.id)
    reloadQueueFromCache()
  }

  func trashCurrent() async {
    guard let task = currentTask else { return }
    await syncService.trashTask(taskID: task.id)
    reloadQueueFromCache()
  }

  func skipCurrent() {
    guard let task = currentTask else { return }
    popCurrent()
    queue.append(task)
  }

  private func popCurrent() {
    guard !queue.isEmpty else { return }
    queue = Array(queue.dropFirst())
  }

  private func reloadQueueFromCache() {
    do {
      let fetched = try repository.fetchTasks(for: .inbox, on: Date()).map(TaskDisplayModel.init)
      queue = fetched
      if syncService.lastError == nil {
        lastError = nil
      }
      let ids = Set(fetched.map { $0.id })
      try repository.pruneTasks(
        matching: { entity in
          entity.isInboxCandidate
        }, keepingIDs: ids)
    } catch {
      lastError = error.localizedDescription
    }
  }

}
