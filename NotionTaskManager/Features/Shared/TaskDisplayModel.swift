import Foundation

struct TaskDisplayModel: Identifiable {
    let task: TaskEntity

    var id: String { task.notionID }
    var title: String { task.name }
    var status: TaskStatus { task.status }
    var timestamp: Date? { task.timestamp }
    var timeslot: TaskTimeslot? { task.timeslot }
    var priority: TaskPriority? { task.priority }
    var type: TaskType? { task.type }
    var memo: String? { task.memo }
    var endTime: Date? { task.endTime }
    var startTime: Date? { task.startTime }
    var deadline: Date? { task.deadline }
    var bookmarkURL: URL? { task.bookmarkURL }
    var url: URL? { bookmarkURL ?? task.url }

    var timeslotLabel: String {
        timeslot?.rawValue ?? "Unscheduled"
    }

    var bookmarkLabel: String? {
        guard let url else { return nil }
        if let host = url.host, !host.isEmpty {
            return host
        }
        return url.absoluteString
    }

    var resolvedType: TaskType {
        task.type ?? .nextAction
    }

    init(task: TaskEntity) {
        self.task = task
    }
}
