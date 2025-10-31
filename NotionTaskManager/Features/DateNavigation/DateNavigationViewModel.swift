import Combine
import Foundation
import SwiftUI

@MainActor
final class DateNavigationViewModel: ObservableObject {
    @Published var selectedDate: Date
    @Published var todoTasks: [TaskDisplayModel] = []
    @Published var completedTasks: [TaskDisplayModel] = []
    @Published var inProgressTasks: [TaskDisplayModel] = []
    @Published var inboxTasks: [TaskDisplayModel] = []
    @Published var overdueTasks: [TaskDisplayModel] = []
    @Published var lastError: String?
    @Published var isLoading = false

    private let repository: TaskRepositoryProtocol
    private let syncService: TaskSyncService?
    private var cancellables: Set<AnyCancellable> = []

    private static let timeslotOrder: [TaskTimeslot?] = [
        .morning, .forenoon, .afternoon, .evening, nil,
    ]

    init(
        repository: TaskRepositoryProtocol,
        syncService: TaskSyncService?,
        initialDate: Date = .todayInJST()
    ) {
        self.repository = repository
        self.syncService = syncService
        self.selectedDate = initialDate

        if let syncService {
            syncService.$lastError
                .receive(on: RunLoop.main)
                .sink { [weak self] error in
                    guard let self else { return }
                    self.lastError = error
                    if error != nil {
                        Task { await self.loadFromCache() }
                    }
                }
                .store(in: &cancellables)
        }
    }

    var hasInboxTasks: Bool { !inboxTasks.isEmpty }
    var hasOverdueTasks: Bool { !overdueTasks.isEmpty }

    var todoGroups: [(slot: TaskTimeslot?, title: String, tint: Color, tasks: [TaskDisplayModel])] {
        let grouped = Dictionary(grouping: todoTasks, by: { $0.timeslot })
        return Self.timeslotOrder.compactMap { slot in
            guard let tasks = grouped[slot], !tasks.isEmpty else { return nil }
            let title = slot?.rawValue ?? "Unscheduled"
            return (slot, title, TaskPalette.tint(for: slot), tasks)
        }
    }

    /// Selects a new date and loads tasks (cache-first, then refresh date only)
    func selectDate(_ date: Date) async {
        selectedDate = date

        // Load from cache immediately (< 300ms)
        await loadFromCache()

        // Refresh only the selected date from Notion (excludes Inbox/Overdue)
        guard let syncService else { return }
        await syncService.refreshDateOnly(for: date)

        // Update with fresh data after refresh completes
        await loadFromCache()
    }

    /// Manually refresh all tasks for the selected date (including Inbox and Overdue)
    func refreshTasks() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        guard let syncService else {
            await loadFromCache()
            return
        }

        await syncService.refresh(for: selectedDate)
        await loadFromCache()
    }

    /// Loads tasks from local cache for the selected date
    private func loadFromCache() async {
        do {
            todoTasks = try repository.fetchTasks(for: .todayTodo, on: selectedDate)
                .map(TaskDisplayModel.init)
            completedTasks = try repository.fetchTasks(for: .todayCompleted, on: selectedDate)
                .map(TaskDisplayModel.init)
            inProgressTasks = try repository.fetchTasks(for: .inProgress, on: selectedDate)
                .map(TaskDisplayModel.init)
            inboxTasks = try repository.fetchTasks(for: .inbox, on: selectedDate)
                .map(TaskDisplayModel.init)
            overdueTasks = try repository.fetchTasks(for: .overdue, on: selectedDate)
                .map(TaskDisplayModel.init)

            #if DEBUG
                print(
                    "[DateNavigation] 📦 Todo: \(todoTasks.count), ✅ Completed: \(completedTasks.count), ⚡️ InProgress: \(inProgressTasks.count), 📬 Inbox: \(inboxTasks.count), ⏰ Overdue: \(overdueTasks.count)"
                )
            #endif
        } catch {
            lastError = error.localizedDescription
            #if DEBUG
                print("[DateNavigation] ❌ Fetch error: \(error)")
            #endif
        }
    }

    // MARK: - Task Actions

    func startTask(_ model: TaskDisplayModel) async {
        guard let syncService else { return }
        await syncService.startTask(taskID: model.id)
        await loadFromCache()
    }

    func completeTask(_ model: TaskDisplayModel) async {
        guard let syncService else { return }
        await syncService.completeTask(taskID: model.id)
        await loadFromCache()
    }

    func cancelTask(_ model: TaskDisplayModel) async {
        guard let syncService else { return }
        await syncService.cancelTask(taskID: model.id)
        await loadFromCache()
    }

    func trashTask(_ model: TaskDisplayModel) async {
        var changes = TaskEditChanges()
        changes.type = .set(.trash)
        await applyEdits(changes, to: model)
    }

    func applyEdits(_ changes: TaskEditChanges, to model: TaskDisplayModel) async {
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

        await loadFromCache()
    }
}
