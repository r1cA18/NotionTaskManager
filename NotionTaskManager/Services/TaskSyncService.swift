import Combine
import Foundation

@MainActor
final class TaskSyncService: ObservableObject {
    @Published private(set) var isSyncing = false
    @Published private(set) var lastError: String?
    @Published private(set) var syncProgress: SyncProgress = .idle
    
    let operationQueue = SyncOperationQueue()
    
    private let dependencies: AppDependencies
    private let repository: TaskRepositoryProtocol
    private let client: NotionClientProtocol
    private let mapper: NotionTaskMapper
    
    private var activeSyncTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    enum SyncProgress: Equatable {
        case idle
        case fetchingTasks
        case fetchingBookmarks(current: Int, total: Int)
        case processing
        case completed
        case failed(String)
    }
    
    init(
        dependencies: AppDependencies,
        repository: TaskRepositoryProtocol,
        client: NotionClientProtocol? = nil,
        mapper: NotionTaskMapper
    ) {
        self.dependencies = dependencies
        self.repository = repository
        self.client = client ?? dependencies.notionClient
        self.mapper = mapper
        
        // Subscribe to operation queue changes for error propagation
        operationQueue.$failedOperations
            .receive(on: RunLoop.main)
            .sink { [weak self] failed in
                if let firstFailed = failed.values.first {
                    self?.lastError = "タスク同期に失敗しました。再試行してください。"
                } else if self?.operationQueue.pendingOperations.isEmpty == true {
                    self?.lastError = nil
                }
            }
            .store(in: &cancellables)
    }
    
    /// Check if a specific task has pending changes
    func hasPendingChanges(for taskID: String) -> Bool {
        operationQueue.hasPendingOperation(for: taskID)
    }
    
    /// Check if a specific task is currently being synced
    func isTaskSyncing(_ taskID: String) -> Bool {
        operationQueue.isProcessing(taskID)
    }
    
    /// Refreshes tasks for the given date, including Inbox and Overdue tasks
    func refresh(for date: Date) async {
        await performSync(for: date, includeInboxAndOverdue: true)
    }
    
    /// Refreshes only tasks for the specific date (excludes Inbox and Overdue)
    func refreshDateOnly(for date: Date) async {
        await performSync(for: date, includeInboxAndOverdue: false)
    }
    
    private func performSync(for date: Date, includeInboxAndOverdue: Bool) async {
        // Cancel any existing sync
        activeSyncTask?.cancel()
        
        // Wait if already syncing
        if isSyncing {
            var attempts = 0
            while isSyncing && attempts < 50 {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                attempts += 1
            }
        }
        
        guard let credentials = dependencies.currentCredentials() else {
            lastError = "Missing Notion credentials."
            syncProgress = .failed("Missing credentials")
            return
        }
        
        isSyncing = true
        syncProgress = .fetchingTasks
        defer {
            isSyncing = false
            if syncProgress != .failed(lastError ?? "") {
                syncProgress = .completed
            }
        }
        
        let dayString = Self.dayFormatter.string(from: date)
        let scope = includeInboxAndOverdue ? "full (date + inbox + overdue)" : "date only"
        log("[TaskSyncService] Fetching tasks for date: \(dayString) [\(scope)]")
        
        let syncTask = Task { @MainActor in
            do {
                var cursor: String?
                var snapshots: [TaskSnapshot] = []
                
                let filter = includeInboxAndOverdue
                    ? TaskScopeMatcher.combinedDailyFilter(dayString: dayString)
                    : TaskScopeMatcher.dateOnlyFilter(dayString: dayString)
                
                repeat {
                    if Task.isCancelled { return }
                    
                    let request = NotionDatabaseQueryRequest(filter: filter, pageSize: 100, startCursor: cursor)
                    let response = try await client.queryDatabase(credentials: credentials, request: request)
                    let mapped = response.results.compactMap(mapper.snapshot(from:))
                    snapshots.append(contentsOf: mapped)
                    cursor = response.hasMore ? response.nextCursor : nil
                } while cursor != nil
                
                if Task.isCancelled { return }
                
                // Fetch bookmarks in parallel with progress tracking
                let tasksNeedingBookmarks = snapshots.enumerated().filter { $0.element.bookmarkURL == nil }
                let total = tasksNeedingBookmarks.count
                var completed = 0
                
                if total > 0 {
                    syncProgress = .fetchingBookmarks(current: 0, total: total)
                }
                
                // Process bookmarks in parallel batches
                let batchSize = 8 // Increased from 5 for better performance
                for batchStart in stride(from: 0, to: tasksNeedingBookmarks.count, by: batchSize) {
                    if Task.isCancelled { return }
                    
                    let batchEnd = min(batchStart + batchSize, tasksNeedingBookmarks.count)
                    let batch = Array(tasksNeedingBookmarks[batchStart..<batchEnd])
                    
                    await withTaskGroup(of: (Int, URL?).self) { group in
                        for (index, snapshot) in batch {
                            group.addTask { [self] in
                                do {
                                    if let bookmark = try await self.client.firstBookmarkURL(
                                        credentials: credentials, pageID: snapshot.notionID
                                    ) {
                                        return (index, bookmark)
                                    }
                                } catch {
                                    // Silently fail bookmark fetching - it's not critical
                                }
                                return (index, nil)
                            }
                        }
                        
                        for await (index, url) in group {
                            if let url {
                                snapshots[index].bookmarkURL = url
                            }
                            completed += 1
                            syncProgress = .fetchingBookmarks(current: completed, total: total)
                        }
                    }
                }
                
                if Task.isCancelled { return }
                
                syncProgress = .processing
                
                try repository.upsert(snapshots: snapshots)
                var ids = Set(snapshots.map(\.notionID))

                // Protect tasks with pending/failed sync operations from pruning
                for taskID in self.operationQueue.pendingOperations.keys {
                    ids.insert(taskID)
                }
                for taskID in self.operationQueue.failedOperations.keys {
                    ids.insert(taskID)
                }

                // Prune strategy differs based on scope
                if includeInboxAndOverdue {
                    try repository.pruneTasks(
                        matching: { entity in
                            entity.isInboxCandidate
                                || entity.isOverdueCandidate
                                || self.isSameDay(entity.timestamp, comparedTo: date)
                                || self.isSameDay(entity.startTime, comparedTo: date)
                                || self.isSameDay(entity.endTime, comparedTo: date)
                        },
                        keepingIDs: ids
                    )
                } else {
                    try repository.pruneTasks(
                        matching: { entity in
                            self.isSameDay(entity.timestamp, comparedTo: date)
                                || self.isSameDay(entity.startTime, comparedTo: date)
                                || self.isSameDay(entity.endTime, comparedTo: date)
                        },
                        keepingIDs: ids
                    )
                }
                
                lastError = nil
                syncProgress = .completed
            } catch is CancellationError {
                log("[NotionSync] Refresh cancelled (view disposed)")
            } catch let error as URLError where error.code == .cancelled {
                log("[NotionSync] URLSession cancelled request")
            } catch let error as NotionClientError {
                lastError = error.localizedDescription
                syncProgress = .failed(error.localizedDescription)
                log("[NotionSync] NotionClientError \(error)")
            } catch {
                lastError = error.localizedDescription
                syncProgress = .failed(error.localizedDescription)
                log("[NotionSync] Unexpected error \(error)")
            }
        }
        
        activeSyncTask = syncTask
        await syncTask.value
    }
    
    func startTask(taskID: String) async {
        guard let credentials = dependencies.currentCredentials() else {
            lastError = "Missing Notion credentials."
            return
        }
        guard
            let entity = try? repository.task(withID: taskID),
            let snapshot = try? repository.snapshot(taskID: taskID)
        else {
            lastError = "Failed to locate task."
            return
        }
        
        let startedAt = Date()
        let needsTimestamp = snapshot.timestamp == nil
        
        // Optimistic update
        do {
            try repository.startTask(entity, startedAt: startedAt)
        } catch {
            lastError = error.localizedDescription
            return
        }
        
        let operation = SyncOperation(
            taskID: taskID,
            operationType: .start
        ) { [self] in
            // Unarchive first
            let unarchiveRequest = NotionPageUpdateRequest(
                properties: [:],
                archived: false
            )
            _ = try await client.updatePage(
                credentials: credentials,
                pageID: taskID,
                request: unarchiveRequest
            )
            
            // Update properties
            let request = NotionPageUpdateRequest(
                properties: patchProperties(
                    status: .inProgress,
                    start: .set(startedAt),
                    end: .ignore,
                    timestamp: needsTimestamp ? .set(startedAt) : .ignore
                )
            )
            _ = try await client.updatePage(
                credentials: credentials,
                pageID: taskID,
                request: request
            )
        } rollback: { [self] in
            do {
                try repository.overwrite(taskID: taskID, with: snapshot)
            } catch {
                log("[NotionSync] Failed to rollback task \(taskID): \(error)")
            }
        }
        
        operationQueue.enqueue(operation)
    }
    
    func completeTask(taskID: String) async {
        guard let credentials = dependencies.currentCredentials() else {
            lastError = "Missing Notion credentials."
            return
        }
        guard
            let entity = try? repository.task(withID: taskID),
            let snapshot = try? repository.snapshot(taskID: taskID)
        else {
            lastError = "Failed to locate task."
            return
        }
        
        let completedAt = Date()
        let completionDay = Self.tokyoStartOfDay(for: completedAt)
        
        // Optimistic update
        do {
            try repository.completeTask(entity, completedAt: completedAt)
        } catch {
            lastError = error.localizedDescription
            return
        }
        
        let operation = SyncOperation(
            taskID: taskID,
            operationType: .complete
        ) { [self] in
            let unarchiveRequest = NotionPageUpdateRequest(
                properties: [:],
                archived: false
            )
            _ = try await client.updatePage(
                credentials: credentials,
                pageID: taskID,
                request: unarchiveRequest
            )
            
            let request = NotionPageUpdateRequest(
                properties: patchProperties(
                    status: .complete,
                    start: .ignore,
                    end: .set(completedAt),
                    timestamp: .set(completionDay)
                )
            )
            _ = try await client.updatePage(
                credentials: credentials,
                pageID: taskID,
                request: request
            )
        } rollback: { [self] in
            do {
                try repository.overwrite(taskID: taskID, with: snapshot)
            } catch {
                log("[NotionSync] Failed to rollback task \(taskID): \(error)")
            }
        }
        
        operationQueue.enqueue(operation)
    }
    
    func cancelTask(taskID: String) async {
        guard let credentials = dependencies.currentCredentials() else {
            lastError = "Missing Notion credentials."
            return
        }
        guard
            let entity = try? repository.task(withID: taskID),
            let snapshot = try? repository.snapshot(taskID: taskID)
        else {
            lastError = "Failed to locate task."
            return
        }
        
        // Optimistic update
        do {
            try repository.cancelTask(entity)
        } catch {
            lastError = error.localizedDescription
            return
        }
        
        let operation = SyncOperation(
            taskID: taskID,
            operationType: .cancel
        ) { [self] in
            let unarchiveRequest = NotionPageUpdateRequest(
                properties: [:],
                archived: false
            )
            _ = try await client.updatePage(
                credentials: credentials,
                pageID: taskID,
                request: unarchiveRequest
            )
            
            let request = NotionPageUpdateRequest(
                properties: patchProperties(
                    status: .toDo,
                    start: .clear,
                    end: .clear,
                    timestamp: .ignore
                )
            )
            _ = try await client.updatePage(
                credentials: credentials,
                pageID: taskID,
                request: request
            )
        } rollback: { [self] in
            do {
                try repository.overwrite(taskID: taskID, with: snapshot)
            } catch {
                log("[NotionSync] Failed to rollback task \(taskID): \(error)")
            }
        }
        
        operationQueue.enqueue(operation)
    }
    
    func trashTask(taskID: String) async {
        guard let credentials = dependencies.currentCredentials() else {
            lastError = "Missing Notion credentials."
            return
        }
        guard let snapshot = try? repository.snapshot(taskID: taskID) else {
            lastError = "Failed to locate task."
            return
        }
        
        // Optimistic update
        do {
            try repository.update(taskID: taskID) { entity in
                entity.type = .trash
                entity.status = .toDo
            }
        } catch {
            lastError = error.localizedDescription
            return
        }
        
        let operation = SyncOperation(
            taskID: taskID,
            operationType: .trash
        ) { [self] in
            let unarchiveRequest = NotionPageUpdateRequest(
                properties: [:],
                archived: false
            )
            _ = try await client.updatePage(
                credentials: credentials,
                pageID: taskID,
                request: unarchiveRequest
            )
            
            let request = NotionPageUpdateRequest(
                properties: [
                    "Type": selectProperty(name: TaskType.trash.rawValue),
                    "Status": statusProperty(.toDo),
                ]
            )
            _ = try await client.updatePage(
                credentials: credentials,
                pageID: taskID,
                request: request
            )
        } rollback: { [self] in
            do {
                try repository.overwrite(taskID: taskID, with: snapshot)
            } catch {
                log("[NotionSync] Failed to rollback task \(taskID): \(error)")
            }
        }
        
        operationQueue.enqueue(operation)
    }
    
    func convertToNextAction(taskID: String) async {
        guard let credentials = dependencies.currentCredentials() else {
            lastError = "Missing Notion credentials."
            return
        }
        guard let snapshot = try? repository.snapshot(taskID: taskID) else {
            lastError = "Failed to locate task."
            return
        }
        
        let today = Self.tokyoStartOfDay(for: Date())
        let shouldUpdateTimestamp: Bool = {
            if let timestamp = snapshot.timestamp {
                return timestamp < today
            }
            return true
        }()
        
        // Optimistic update
        do {
            try repository.update(taskID: taskID) { entity in
                entity.type = .nextAction
                entity.status = .toDo
                if shouldUpdateTimestamp {
                    entity.timestamp = today
                }
            }
        } catch {
            lastError = error.localizedDescription
            return
        }
        
        let operation = SyncOperation(
            taskID: taskID,
            operationType: .convert
        ) { [self] in
            let unarchiveRequest = NotionPageUpdateRequest(
                properties: [:],
                archived: false
            )
            _ = try await client.updatePage(
                credentials: credentials,
                pageID: taskID,
                request: unarchiveRequest
            )
            
            var properties: [String: JSONValue] = [
                "Type": selectProperty(name: TaskType.nextAction.rawValue),
                "Status": statusProperty(.toDo),
            ]
            if shouldUpdateTimestamp {
                properties["Timestamp"] = timestampProperty(from: today)
            }
            let request = NotionPageUpdateRequest(properties: properties)
            _ = try await client.updatePage(
                credentials: credentials, pageID: taskID, request: request
            )
        } rollback: { [self] in
            do {
                try repository.overwrite(taskID: taskID, with: snapshot)
            } catch {
                log("[NotionSync] Failed to rollback task \(taskID): \(error)")
            }
        }
        
        operationQueue.enqueue(operation)
    }
    
    func updateTask(taskID: String, changes: TaskEditChanges) async {
        guard !changes.isEmpty else { return }
        guard let credentials = dependencies.currentCredentials() else {
            lastError = "Missing Notion credentials."
            return
        }
        guard let snapshot = try? repository.snapshot(taskID: taskID) else {
            lastError = "Failed to locate task."
            return
        }
        
        let properties = properties(from: changes)
        guard !properties.isEmpty else { return }
        
        // Optimistic update
        do {
            try repository.update(taskID: taskID) { entity in
                changes.apply(to: entity)
            }
        } catch {
            lastError = error.localizedDescription
            return
        }
        
        let operation = SyncOperation(
            taskID: taskID,
            operationType: .update
        ) { [self] in
            let unarchiveRequest = NotionPageUpdateRequest(
                properties: [:],
                archived: false
            )
            _ = try await client.updatePage(
                credentials: credentials,
                pageID: taskID,
                request: unarchiveRequest
            )
            
            let request = NotionPageUpdateRequest(properties: properties)
            _ = try await client.updatePage(
                credentials: credentials,
                pageID: taskID,
                request: request
            )
        } rollback: { [self] in
            do {
                try repository.overwrite(taskID: taskID, with: snapshot)
            } catch {
                log("[NotionSync] Failed to rollback task \(taskID): \(error)")
            }
        }
        
        operationQueue.enqueue(operation)
    }
    
    // MARK: - Property Builders
    
    private enum DatePatch {
        case set(Date)
        case clear
        case ignore
    }
    
    private func patchProperties(
        status: TaskStatus, start: DatePatch, end: DatePatch, timestamp: DatePatch
    ) -> [String: JSONValue] {
        var properties: [String: JSONValue] = ["Status": statusProperty(status)]
        
        switch start {
        case .set(let date): properties["StartTime"] = dateProperty(from: date)
        case .clear: properties["StartTime"] = nullDateProperty()
        case .ignore: break
        }
        
        switch end {
        case .set(let date): properties["EndTime"] = dateProperty(from: date)
        case .clear: properties["EndTime"] = nullDateProperty()
        case .ignore: break
        }
        
        switch timestamp {
        case .set(let date): properties["Timestamp"] = timestampProperty(from: date)
        case .clear: properties["Timestamp"] = nullDateProperty()
        case .ignore: break
        }
        
        return properties
    }
    
    private func statusProperty(_ status: TaskStatus) -> JSONValue {
        .object(["status": .object(["name": .string(status.rawValue)])])
    }
    
    private func dateProperty(from date: Date) -> JSONValue {
        .object(["date": .object(["start": .string(Self.isoDateTimeFormatter.string(from: date))])])
    }
    
    private func timestampProperty(from date: Date) -> JSONValue {
        .object(["date": .object(["start": .string(Self.dayFormatter.string(from: date))])])
    }
    
    private func nullDateProperty() -> JSONValue {
        .object(["date": .null])
    }
    
    private func titleProperty(content: String) -> JSONValue {
        let textObject: JSONValue = .object([
            "type": .string("text"),
            "text": .object(["content": .string(content)])
        ])
        return .object(["title": .array([textObject])])
    }
    
    private func selectProperty(name: String?) -> JSONValue {
        if let name {
            return .object(["select": .object(["name": .string(name)])])
        } else {
            return .object(["select": .null])
        }
    }
    
    private func richTextProperty(content: String?) -> JSONValue {
        guard let content, !content.isEmpty else {
            return .object(["rich_text": .array([])])
        }
        let textObject: JSONValue = .object([
            "type": .string("text"),
            "text": .object(["content": .string(content)]),
        ])
        return .object(["rich_text": .array([textObject])])
    }
    
    private func properties(from changes: TaskEditChanges) -> [String: JSONValue] {
        var properties: [String: JSONValue] = [:]
        
        switch changes.name {
        case .set(let value):
            properties["Name"] = titleProperty(content: value)
        case .clear, .unchanged:
            break
        }
        
        switch changes.priority {
        case .set(let value):
            properties["Priority"] = selectProperty(name: value?.rawValue)
        case .clear:
            properties["Priority"] = selectProperty(name: nil)
        case .unchanged:
            break
        }
        
        switch changes.timeslot {
        case .set(let value):
            properties["Timeslot"] = selectProperty(name: value?.rawValue)
        case .clear:
            properties["Timeslot"] = selectProperty(name: nil)
        case .unchanged:
            break
        }
        
        switch changes.type {
        case .set(let value):
            let resolved = value ?? .nextAction
            properties["Type"] = selectProperty(name: resolved.rawValue)
        case .clear:
            properties["Type"] = selectProperty(name: TaskType.nextAction.rawValue)
        case .unchanged:
            break
        }
        
        switch changes.timestamp {
        case .set(let value):
            if let value {
                properties["Timestamp"] = timestampProperty(from: value)
            } else {
                properties["Timestamp"] = nullDateProperty()
            }
        case .clear:
            properties["Timestamp"] = nullDateProperty()
        case .unchanged:
            break
        }
        
        switch changes.deadline {
        case .set(let value):
            if let value {
                properties["Deadline"] = dateProperty(from: value)
            } else {
                properties["Deadline"] = nullDateProperty()
            }
        case .clear:
            properties["Deadline"] = nullDateProperty()
        case .unchanged:
            break
        }
        
        switch changes.memo {
        case .set(let value):
            properties["Memo"] = richTextProperty(content: value)
        case .clear:
            properties["Memo"] = richTextProperty(content: nil)
        case .unchanged:
            break
        }
        
        switch changes.status {
        case .set(let value):
            properties["Status"] = statusProperty(value)
        case .clear, .unchanged:
            break
        }
        
        return properties
    }
    
    private func isSameDay(_ date: Date?, comparedTo target: Date) -> Bool {
        guard let date else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .tokyo
        let lhs = calendar.startOfDay(for: date)
        let rhs = calendar.startOfDay(for: target)
        return lhs == rhs
    }
    
    private nonisolated func log(_ message: String) {
        #if DEBUG
        print(message)
        #endif
    }
    
    private static func tokyoStartOfDay(for date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .tokyo
        return calendar.startOfDay(for: date)
    }
    
    private static let isoDateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime, .withFractionalSeconds, .withColonSeparatorInTimeZone,
        ]
        formatter.timeZone = .tokyo
        return formatter
    }()
    
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .tokyo
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
