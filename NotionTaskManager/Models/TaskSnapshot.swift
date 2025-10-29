import Foundation

struct TaskSnapshot {
    let notionID: String
    let name: String
    var memo: String?
    var status: TaskStatus
    var timestamp: Date?
    var timeslot: TaskTimeslot?
    var endTime: Date?
    var startTime: Date?
    var priority: TaskPriority?
    var projectIDs: [String]
    var type: TaskType?
    var noteType: String?
    var articleGenres: [String]
    var permanentTags: [String]
    var deadline: Date?
    var spaceName: String?
    var url: URL?
    var bookmarkURL: URL?
    var updatedAt: Date
    var createdAt: Date
}

extension TaskSnapshot {
    init(task: TaskEntity) {
        self.init(
            notionID: task.notionID,
            name: task.name,
            memo: task.memo,
            status: task.status,
            timestamp: task.timestamp,
            timeslot: task.timeslot,
            endTime: task.endTime,
            startTime: task.startTime,
            priority: task.priority,
            projectIDs: task.projectIDs,
            type: task.type,
            noteType: task.noteType,
            articleGenres: task.articleGenres,
            permanentTags: task.permanentTags,
            deadline: task.deadline,
            spaceName: task.spaceName,
            url: task.url,
            bookmarkURL: task.bookmarkURL,
            updatedAt: task.updatedAt,
            createdAt: task.createdAt
        )
    }
}
