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
    
    enum OperationType: String {
        case start
        case complete
        case cancel
        case trash
        case convert
        case update
    }
    
    init(
        taskID: String,
        operationType: OperationType,
        maxRetries: Int = 2,
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
    }
}

/// Manages pending sync operations with retry logic and conflict prevention
@MainActor
final class SyncOperationQueue: ObservableObject {
    @Published private(set) var pendingOperations: [String: SyncOperation] = [:]
    @Published private(set) var failedOperations: [String: SyncOperation] = [:]
    @Published private(set) var processingTaskIDs: Set<String> = []
    
    private var operationTasks: [String: Task<Void, Never>] = [:]
    
    /// Check if a task has a pending operation
    func hasPendingOperation(for taskID: String) -> Bool {
        pendingOperations[taskID] != nil || processingTaskIDs.contains(taskID)
    }
    
    /// Check if a task is currently being processed
    func isProcessing(_ taskID: String) -> Bool {
        processingTaskIDs.contains(taskID)
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
        
        pendingOperations[taskID] = operation
        failedOperations.removeValue(forKey: taskID)
        
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
        enqueue(operation)
    }
    
    /// Clear a failed operation without retrying
    func clearFailedOperation(for taskID: String) {
        failedOperations.removeValue(forKey: taskID)
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
    }
    
    private func processOperation(taskID: String) async {
        guard var operation = pendingOperations[taskID] else { return }
        
        processingTaskIDs.insert(taskID)
        defer { processingTaskIDs.remove(taskID) }
        
        do {
            try await operation.execute()
            pendingOperations.removeValue(forKey: taskID)
            operationTasks.removeValue(forKey: taskID)
            
            #if DEBUG
            print("[SyncQueue] ✅ Operation \(operation.operationType) completed for task \(taskID)")
            #endif
        } catch {
            if Task.isCancelled { return }
            
            operation.retryCount += 1
            
            if operation.retryCount < operation.maxRetries {
                #if DEBUG
                print("[SyncQueue] ⚠️ Retry \(operation.retryCount)/\(operation.maxRetries) for \(taskID): \(error)")
                #endif
                
                // Exponential backoff
                let delay = Double(operation.retryCount) * 1.5
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                if !Task.isCancelled {
                    pendingOperations[taskID] = operation
                    await processOperation(taskID: taskID)
                }
            } else {
                #if DEBUG
                print("[SyncQueue] ❌ Operation failed after \(operation.retryCount) retries for \(taskID): \(error)")
                #endif
                
                // Move to failed operations
                pendingOperations.removeValue(forKey: taskID)
                operationTasks.removeValue(forKey: taskID)
                failedOperations[taskID] = operation
                
                // Execute rollback
                await operation.rollback()
            }
        }
    }
}
