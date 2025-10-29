import Foundation
import SwiftData

enum TaskStatus: String, Codable, CaseIterable, Identifiable, Equatable, Hashable {
  case toDo = "To Do"
  case inProgress = "In Progress"
  case complete = "Complete"

  var id: String { rawValue }
}

enum TaskTimeslot: String, Codable, CaseIterable, Identifiable, Equatable, Hashable {
  case morning = "Morning"
  case forenoon = "Forenoon"
  case afternoon = "Afternoon"
  case evening = "Evening"

  var id: String { rawValue }
}

enum TaskPriority: String, Codable, CaseIterable, Identifiable, Equatable, Hashable {
  case fourStars = "★★★★"
  case threeAndHalf = "★★★☆"
  case twoStars = "★★☆☆"
  case oneStar = "★☆☆☆"

  var id: String { rawValue }
}

enum TaskType: String, Codable, CaseIterable, Identifiable, Equatable, Hashable {
  case nextAction = "NextAction"
  case someday = "Someday"
  case waiting = "Waiting"
  case trash = "Trash"

  var id: String { rawValue }
}

@Model
final class TaskEntity {
  @Attribute(.unique) var notionID: String
  var name: String
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

  init(
    notionID: String,
    name: String,
    memo: String? = nil,
    status: TaskStatus,
    timestamp: Date? = nil,
    timeslot: TaskTimeslot? = nil,
    endTime: Date? = nil,
    startTime: Date? = nil,
    priority: TaskPriority? = nil,
    projectIDs: [String] = [],
    type: TaskType? = nil,
    noteType: String? = nil,
    articleGenres: [String] = [],
    permanentTags: [String] = [],
    deadline: Date? = nil,
    spaceName: String? = nil,
    url: URL? = nil,
    bookmarkURL: URL? = nil,
    updatedAt: Date,
    createdAt: Date
  ) {
    self.notionID = notionID
    self.name = name
    self.memo = memo
    self.status = status
    self.timestamp = timestamp
    self.timeslot = timeslot
    self.endTime = endTime
    self.startTime = startTime
    self.priority = priority
    self.projectIDs = projectIDs
    self.type = type
    self.noteType = noteType
    self.articleGenres = articleGenres
    self.permanentTags = permanentTags
    self.deadline = deadline
    self.spaceName = spaceName
    self.url = url
    self.bookmarkURL = bookmarkURL
    self.updatedAt = updatedAt
    self.createdAt = createdAt
  }
}

extension TaskEntity {
  var isInboxCandidate: Bool {
    status == .toDo && type == nil && (noteType == nil || noteType?.isEmpty == true)
  }

  var isOverdueCandidate: Bool {
    guard status == .toDo || status == .inProgress else { return false }
    guard let timestamp else { return false }
    if let type {
      if type == .waiting || type == .trash {
        return false
      }
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .tokyo
    let today = calendar.startOfDay(for: Date())
    return timestamp < today
  }
}
