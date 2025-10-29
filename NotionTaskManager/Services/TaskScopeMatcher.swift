import Foundation

enum TaskScopeMatcher {
  static func matches(
    _ task: TaskEntity,
    scope: TaskScope,
    on date: Date,
    boundaries: DateBoundaries
  ) -> Bool {
    switch scope {
    case .inbox:
      return task.isInboxCandidate
    case .todayTodo:
      return task.status == .toDo && task.timestamp.map { boundaries.contains($0) } == true
    case .todayCompleted:
      guard task.status == .complete, let endTime = task.endTime else { return false }
      return boundaries.contains(endTime)
    case .inProgress:
      guard task.status == .inProgress else { return false }
      let timestampMatches = task.timestamp.map { boundaries.contains($0) } == true
      let startMatches = task.startTime.map { boundaries.contains($0) } == true
      return timestampMatches || startMatches
    case .overdue:
      guard task.status == .toDo || task.status == .inProgress else { return false }
      if let type = task.type, type == .waiting || type == .trash {
        return false
      }
      guard let timestamp = task.timestamp else { return false }
      return timestamp < boundaries.startOfDay
    }
  }

  static func notionFilter(for scope: TaskScope, dayString: String) -> JSONValue? {
    switch scope {
    case .todayTodo:
      return JSONValue.object([
        "property": .string("Timestamp"),
        "date": .object([
          "equals": .string(dayString)
        ]),
      ])
    case .inbox:
      return JSONValue.object([
        "and": .array([
          selectIsEmpty("Type"),
          statusEquals(TaskStatus.toDo.rawValue),
          selectIsEmpty("NoteType"),
        ])
      ])
    default:
      return nil
    }
  }

  static func combinedDailyFilter(dayString: String) -> JSONValue {
    var filters: [JSONValue] = []
    if let today = notionFilter(for: .todayTodo, dayString: dayString) {
      filters.append(today)
    }
    if let inbox = notionFilter(for: .inbox, dayString: dayString) {
      filters.append(inbox)
    }
    filters.append(contentsOf: overdueFilters(dayString: dayString))

    return JSONValue.object([
      "or": .array(filters)
    ])
  }

  private static func overdueFilters(dayString: String) -> [JSONValue] {
    let timestampNotEmpty = JSONValue.object([
      "property": .string("Timestamp"),
      "date": .object([
        "is_not_empty": .bool(true)
      ]),
    ])

    let timestampBeforeToday = JSONValue.object([
      "property": .string("Timestamp"),
      "date": .object([
        "before": .string(dayString)
      ]),
    ])

    let statuses: [TaskStatus] = [.toDo, .inProgress]
    let allowedTypes: [TaskType?] = [nil, .nextAction, .someday]

    var filters: [JSONValue] = []
    for status in statuses {
      for type in allowedTypes {
        let typeFilter: JSONValue
        if let type = type {
          typeFilter = selectEquals("Type", type.rawValue)
        } else {
          typeFilter = selectIsEmpty("Type")
        }

        filters.append(
          JSONValue.object([
            "and": .array([
              statusEquals(status.rawValue),
              typeFilter,
              timestampNotEmpty,
              timestampBeforeToday,
            ])
          ])
        )
      }
    }
    return filters
  }

  private static func selectIsEmpty(_ property: String) -> JSONValue {
    JSONValue.object([
      "property": .string(property),
      "select": .object([
        "is_empty": .bool(true)
      ]),
    ])
  }

  private static func selectEquals(_ property: String, _ value: String) -> JSONValue {
    JSONValue.object([
      "property": .string(property),
      "select": .object([
        "equals": .string(value)
      ]),
    ])
  }

  private static func statusEquals(_ value: String) -> JSONValue {
    JSONValue.object([
      "property": .string("Status"),
      "status": .object([
        "equals": .string(value)
      ]),
    ])
  }

  private static func dateIsEmpty(_ property: String) -> JSONValue {
    JSONValue.object([
      "property": .string(property),
      "date": .object([
        "is_empty": .bool(true)
      ]),
    ])
  }
}
