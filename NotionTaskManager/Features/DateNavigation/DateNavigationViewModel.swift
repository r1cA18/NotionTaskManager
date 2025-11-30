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
    @Published var isInitialLoad = true
    
    private let repository: TaskRepositoryProtocol
    private let syncService: TaskSyncService?
    private var cancellables: Set<AnyCancellable> = []
    private var dateChangeTask: Task<Void, Never>?
    
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
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Subscribe to sync service errors
        if let syncService {
            syncService.$lastError
                .receive(on: RunLoop.main)
                .sink { [weak self] error in
                    guard let self else { return }
                    self.lastError = error
                    if error != nil {
                        // Reload from cache on error
                        Task { await self.loadFromCache() }
                    }
                }
                .store(in: &cancellables)
            
            // Subscribe to sync progress for loading state
            syncService.$syncProgress
                .receive(on: RunLoop.main)
                .sink { [weak self] progress in
                    guard let self else { return }
                    switch progress {
                    case .idle, .completed:
                        // Don't immediately set loading to false - let refreshTasks handle it
                        break
                    case .fetchingTasks, .fetchingBookmarks, .processing:
                        // Sync is in progress
                        break
                    case .failed:
                        self.isLoading = false
                    }
                }
                .store(in: &cancellables)
            
            // Subscribe to operation queue for pending changes
            syncService.operationQueue.$failedOperations
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    // Reload cache when operations fail
                    Task { await self?.loadFromCache() }
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
    
    /// Returns true if a task has pending sync operations
    func isTaskSyncing(_ taskID: String) -> Bool {
        syncService?.hasPendingChanges(for: taskID) ?? false
    }
    
    /// Selects a new date and loads tasks (cache-first, then background refresh)
    func selectDate(_ date: Date) async {
        // Cancel any pending date change
        dateChangeTask?.cancel()
        
        let normalizedDate = date.startOfDayInJST()
        selectedDate = normalizedDate
        
        // Load from cache immediately for instant UI
        await loadFromCache()
        
        // Background refresh (date only, excludes Inbox/Overdue for speed)
        dateChangeTask = Task {
            guard let syncService else { return }
            guard !Task.isCancelled else { return }
            
            await syncService.refreshDateOnly(for: normalizedDate)
            
            guard !Task.isCancelled else { return }
            await loadFromCache()
        }
        
        await dateChangeTask?.value
    }
    
    /// Unified refresh method for both pull-to-refresh and button refresh
    func refreshTasks() async {
        guard !isLoading else { return }
        
        isLoading = true
        isInitialLoad = false
        
        defer { isLoading = false }
        
        guard let syncService else {
            await loadFromCache()
            return
        }
        
        // Full refresh including Inbox and Overdue
        await syncService.refresh(for: selectedDate)
        await loadFromCache()
    }
    
    /// Initial load on app launch - prioritizes speed
    func initialLoad() async {
        guard isInitialLoad else { return }
        
        isLoading = true
        defer {
            isLoading = false
            isInitialLoad = false
        }
        
        // First, show cached data immediately
        await loadFromCache()
        
        // Then refresh in background
        guard let syncService else { return }
        await syncService.refresh(for: selectedDate)
        await loadFromCache()
    }
    
    /// Loads tasks from local cache for the selected date
    private func loadFromCache() async {
        do {
            let date = selectedDate
            
            todoTasks = try repository.fetchTasks(for: .todayTodo, on: date)
                .map(TaskDisplayModel.init)
            completedTasks = try repository.fetchTasks(for: .todayCompleted, on: date)
                .map(TaskDisplayModel.init)
            inProgressTasks = try repository.fetchTasks(for: .inProgress, on: date)
                .map(TaskDisplayModel.init)
            inboxTasks = try repository.fetchTasks(for: .inbox, on: date)
                .map(TaskDisplayModel.init)
            overdueTasks = try repository.fetchTasks(for: .overdue, on: date)
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
