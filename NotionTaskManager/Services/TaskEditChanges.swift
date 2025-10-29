import Foundation

struct TaskEditChanges {
    enum Update<T> {
        case unchanged
        case set(T)
        case clear

        var hasChange: Bool {
            switch self {
            case .unchanged: return false
            default: return true
            }
        }
    }

    var priority: Update<TaskPriority?> = .unchanged
    var timeslot: Update<TaskTimeslot?> = .unchanged
    var type: Update<TaskType?> = .unchanged
    var timestamp: Update<Date?> = .unchanged
    var deadline: Update<Date?> = .unchanged
    var memo: Update<String?> = .unchanged
    var status: Update<TaskStatus> = .unchanged

    var name: Update<String> = .unchanged

    var isEmpty: Bool {
        !name.hasChange && !priority.hasChange && !timeslot.hasChange && !type.hasChange &&
        !timestamp.hasChange && !deadline.hasChange && !memo.hasChange &&
        !status.hasChange
    }

    func apply(to entity: TaskEntity) {
        switch name {
        case .set(let value): entity.name = value
        default: break
        }

        switch priority {
        case .set(let value): entity.priority = value
        case .clear: entity.priority = nil
        case .unchanged: break
        }

        switch timeslot {
        case .set(let value): entity.timeslot = value
        case .clear: entity.timeslot = nil
        case .unchanged: break
        }

        switch type {
        case .set(let value): entity.type = value ?? .nextAction
        case .clear: entity.type = .nextAction
        case .unchanged: break
        }

        switch timestamp {
        case .set(let value): entity.timestamp = value
        case .clear: entity.timestamp = nil
        case .unchanged: break
        }

        switch deadline {
        case .set(let value): entity.deadline = value
        case .clear: entity.deadline = nil
        case .unchanged: break
        }

        switch memo {
        case .set(let value): entity.memo = value
        case .clear: entity.memo = nil
        case .unchanged: break
        }

        switch status {
        case .set(let value): entity.status = value
        default: break
        }
    }
}
