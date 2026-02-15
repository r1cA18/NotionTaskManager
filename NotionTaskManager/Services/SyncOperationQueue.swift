import Combine
import Foundation

/// Represents a pending sync operation
struct SyncOperation: Identifiable {
    let id: UUID
    let taskID: String
    let operationType: OperationType
    let execute: () async throws -> Void
    let rollback: () async -> Void
    var retryCount: Int
    let maxRetries: Int
    let createdAt: Date
    var lastError: Error?
    var status: OperationStatus

    enum OperationType: String {
        case start = "開始"
        case complete = "完了"
        case cancel = "キャンセル"
        case trash = "削除"
        case convert = "変換"
        case update = "更新"

        var icon: String {
            switch self {
            case .start: return "play.fill"
            case .complete: return "checkmark.circle.fill"
            case .cancel: return "xmark.circle.fill"
            case .trash: return "trash.fill"
            case .convert: return "arrow.triangle.2.circlepath"
            case .update: return "pencil"
            }
        }
    }

    init(
        taskID: String,
        operationType: OperationType,
        maxRetries: Int = 5,  // Increased from 2 to 5
        execute: @escaping () async throws -> Void,
        rollback: @escaping () async -> Void
    ) {
        self.id = UUID()
        self.taskID = taskID
        self.operationType = operationType
        self.execute = execute
        self.rollback = rollback
        self.retryCount = 0
        self.maxRetries = maxRetries
        self.createdAt = Date()
        self.lastError = nil
        self.status = .pending
    }
}

/// Manages pending sync operations with retry logic and conflict prevention
@MainActor
final class SyncOperationQueue: ObservableObject {
    @Published private(set) var pendingOperations: [String: SyncOperation] = [:]
    @Published private(set) var failedOperations: [String: SyncOperation] = [:]
    @Published private(set) var processingTaskIDs: Set<String> = []

    /// Real-time status for each task (for UI observation)
    @Published private(set) var operationStatuses: [String: OperationStatus] = [:]

    /// Count of operations in various states
    @Published private(set) var pendingCount: Int = 0
    @Published private(set) var failedCount: Int = 0

    /// Last completed operation (for toast notifications)
    @Published var lastCompletedOperation: (taskID: String, type: SyncOperation.OperationType)?

    /// Last failed operation (for toast notifications)
    @Published var lastFailedOperation: (taskID: String, error: SyncError)?

    private var operationTasks: [String: Task<Void, Never>] = [:]

    /// Network monitor reference for pausing on offline
    weak var networkMonitor: NetworkMonitor?

    /// Check if a task has a pending operation
    func hasPendingOperation(for taskID: String) -> Bool {
        pendingOperations[taskID] != nil || processingTaskIDs.contains(taskID)
    }

    /// Check if a task is currently being processed
    func isProcessing(_ taskID: String) -> Bool {
        processingTaskIDs.contains(taskID)
    }

    /// Get status for a specific task
    func status(for taskID: String) -> OperationStatus? {
        operationStatuses[taskID]
    }

    /// Check if there are any pending or failed operations
    var hasUnsyncedChanges: Bool {
        !pendingOperations.isEmpty || !failedOperations.isEmpty
    }

    /// Enqueue an operation for a task
    /// If there's already a pending operation for the same task, it will be cancelled
    func enqueue(_ operation: SyncOperation) {
        let taskID = operation.taskID

        // Cancel any existing operation for this task
        if let existingTask = operationTasks[taskID] {
            existingTask.cancel()
            operationTasks.removeValue(forKey: taskID)
        }

        var op = operation
        op.status = .pending
        pendingOperations[taskID] = op
        failedOperations.removeValue(forKey: taskID)
        operationStatuses[taskID] = .pending
        updateCounts()

        // Start processing
        let task = Task { [weak self] in
            guard let self else { return }
            await self.processOperation(taskID: taskID)
        }
        operationTasks[taskID] = task
    }

    /// Retry a failed operation
    func retryFailedOperation(for taskID: String) {
        guard var operation = failedOperations[taskID] else { return }
        failedOperations.removeValue(forKey: taskID)
        operation.retryCount = 0
        operation.lastError = nil
        operation.status = .pending
        enqueue(operation)
    }

    /// Retry all failed operations
    func retryAllFailed() {
        let failed = failedOperations
        for (taskID, _) in failed {
            retryFailedOperation(for: taskID)
        }
    }

    /// Clear a failed operation without retrying
    func clearFailedOperation(for taskID: String) {
        failedOperations.removeValue(forKey: taskID)
        operationStatuses.removeValue(forKey: taskID)
        updateCounts()
    }

    /// Clear all failed operations
    func clearAllFailed() {
        for taskID in failedOperations.keys {
            operationStatuses.removeValue(forKey: taskID)
        }
        failedOperations.removeAll()
        updateCounts()
    }

    /// Cancel a pending operation
    func cancelOperation(for taskID: String) async {
        if let task = operationTasks[taskID] {
            task.cancel()
            operationTasks.removeValue(forKey: taskID)
        }

        if let operation = pendingOperations.removeValue(forKey: taskID) {
            await operation.rollback()
        }

        processingTaskIDs.remove(taskID)
        operationStatuses.removeValue(forKey: taskID)
        updateCounts()
    }

    /// Resume all pending operations (called when network is restored)
    func resumePendingOperations() async {
        let pending = pendingOperations
        for (taskID, operation) in pending {
            if operationTasks[taskID] == nil {
                let task = Task { [weak self] in
                    guard let self else { return }
                    await self.processOperation(taskID: taskID)
                }
                operationTasks[taskID] = task
            }
        }
    }

    private func processOperation(taskID: String) async {
        guard var operation = pendingOperations[taskID] else { return }

        // Check network status
        if let monitor = networkMonitor, !monitor.isConnected {
            #if DEBUG
            print("[SyncQueue] ⏸️ Network unavailable, pausing operation for \(taskID)")
            #endif
            operation.status = .pending
            pendingOperations[taskID] = operation
            operationStatuses[taskID] = .pending
            return
        }

        processingTaskIDs.insert(taskID)
        operation.status = .executing
        pendingOperations[taskID] = operation
        operationStatuses[taskID] = .executing

        defer {
            processingTaskIDs.remove(taskID)
        }

        do {
            try await operation.execute()

            // Success
            pendingOperations.removeValue(forKey: taskID)
            operationTasks.removeValue(forKey: taskID)
            operationStatuses[taskID] = .completed
            updateCounts()

            // Notify completion
            lastCompletedOperation = (taskID, operation.operationType)

            // Clear completed status after delay
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds
                if self.operationStatuses[taskID] == .completed {
                    self.operationStatuses.removeValue(forKey: taskID)
                }
            }

            #if DEBUG
            print("[SyncQueue] ✅ Operation \(operation.operationType.rawValue) completed for task \(taskID)")
            #endif
        } catch {
            if Task.isCancelled { return }

            operation.retryCount += 1
            operation.lastError = error

            let syncError = mapToSyncError(error)

            if operation.retryCount < operation.maxRetries && syncError.shouldAutoRetry {
                operation.status = .retrying(attempt: operation.retryCount, maxAttempts: operation.maxRetries)
                pendingOperations[taskID] = operation
                operationStatuses[taskID] = operation.status

                #if DEBUG
                print("[SyncQueue] ⚠️ Retry \(operation.retryCount)/\(operation.maxRetries) for \(taskID): \(error)")
                #endif

                // Improved exponential backoff: 1, 2, 4, 8, 16 seconds
                let baseDelay = syncError.retryDelay
                let delay = pow(2.0, Double(operation.retryCount - 1)) * baseDelay
                let cappedDelay = min(delay, 30.0)  // Cap at 30 seconds

                try? await Task.sleep(nanoseconds: UInt64(cappedDelay * 1_000_000_000))

                if !Task.isCancelled {
                    await processOperation(taskID: taskID)
                }
            } else {
                #if DEBUG
                print("[SyncQueue] ❌ Operation failed after \(operation.retryCount) retries for \(taskID): \(error)")
                #endif

                // Move to failed operations
                operation.status = .failed(syncError)
                pendingOperations.removeValue(forKey: taskID)
                operationTasks.removeValue(forKey: taskID)
                failedOperations[taskID] = operation
                operationStatuses[taskID] = .failed(syncError)
                updateCounts()

                // Notify failure
                lastFailedOperation = (taskID, syncError)

                // Execute rollback
                await operation.rollback()
            }
        }
    }

    private func mapToSyncError(_ error: Error) -> SyncError {
        // Map common errors to SyncError
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkUnavailable
            case .timedOut:
                return .timeout
            default:
                return .unknown(message: urlError.localizedDescription)
            }
        }

        // Check for Notion-specific errors
        if let syncError = error as? SyncError {
            return syncError
        }

        return .unknown(message: error.localizedDescription)
    }

    private func updateCounts() {
        pendingCount = pendingOperations.count
        failedCount = failedOperations.count
    }
}
