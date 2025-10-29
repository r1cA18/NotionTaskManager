import Foundation

struct NotionTaskMapper {
  private let iso8601Formatter: ISO8601DateFormatter
  private let fallbackDateFormatter: DateFormatter

  init() {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [
      .withInternetDateTime, .withFractionalSeconds, .withColonSeparatorInTimeZone,
    ]
    iso8601Formatter = formatter

    let fallback = DateFormatter()
    fallback.calendar = Calendar(identifier: .gregorian)
    fallback.locale = Locale(identifier: "en_US_POSIX")
    fallback.timeZone = .tokyo
    fallback.dateFormat = "yyyy-MM-dd"
    fallbackDateFormatter = fallback
  }

  func snapshot(from page: NotionPageObject) -> TaskSnapshot? {
    #if DEBUG
      print("[NotionTaskMapper] Page ID: \(page.id)")
      print("[NotionTaskMapper] Available properties: \(page.properties.keys.sorted())")
    #endif
    guard let nameProperty = page.properties[PropertyKey.name], let name = nameProperty.plainText
    else {
      #if DEBUG
        print("[NotionTaskMapper] ⚠️ Name property not found or empty - skipping page")
      #endif
      return nil
    }

    let memo = page.properties[PropertyKey.memo]?.plainText
    let status =
      page.properties[PropertyKey.status]?.statusValue.flatMap(TaskStatus.init(rawValue:)) ?? .toDo
    let timestamp = page.properties[PropertyKey.timestamp].flatMap { dateValue(from: $0) }
    let timeslot = page.properties[PropertyKey.timeslot]?.selectValue.flatMap(
      TaskTimeslot.init(rawValue:))
    let endTime = page.properties[PropertyKey.endTime].flatMap { dateValue(from: $0) }
    let startTime = page.properties[PropertyKey.startTime].flatMap { dateValue(from: $0) }
    let priority = page.properties[PropertyKey.priority]?.selectValue.flatMap(
      TaskPriority.init(rawValue:))
    let projectIDs = page.properties[PropertyKey.project]?.relationIDs ?? []
    let type =
      page.properties[PropertyKey.type]?.selectValue.flatMap(TaskType.init(rawValue:))
    let noteType = page.properties[PropertyKey.noteType]?.selectValue
    let articleGenres = page.properties[PropertyKey.articleGenre]?.multiSelectNames ?? []
    let permanentTags = page.properties[PropertyKey.permanentTags]?.multiSelectNames ?? []
    let deadline = page.properties[PropertyKey.deadline].flatMap { dateValue(from: $0) }
    let spaceName = page.properties[PropertyKey.spaceName]?.plainText
    let url = page.properties[PropertyKey.url]?.urlValue

    return TaskSnapshot(
      notionID: page.id,
      name: name,
      memo: memo,
      status: status,
      timestamp: timestamp,
      timeslot: timeslot,
      endTime: endTime,
      startTime: startTime,
      priority: priority,
      projectIDs: projectIDs,
      type: type,
      noteType: noteType,
      articleGenres: articleGenres,
      permanentTags: permanentTags,
      deadline: deadline,
      spaceName: spaceName,
      url: url,
      bookmarkURL: nil,
      updatedAt: page.lastEditedTime,
      createdAt: page.createdTime
    )
  }

  private func dateValue(from property: NotionPropertyValue) -> Date? {
    switch property.rawValue {
    case .object(let object):
      if case .string(let start)? = object["start"],
        let date = iso8601Formatter.date(from: start) ?? fallbackDateFormatter.date(from: start)
      {
        return date
      }
      return nil
    default:
      return nil
    }
  }
}

extension NotionTaskMapper {
  fileprivate enum PropertyKey {
    static let name = "Name"
    static let memo = "Memo"
    static let status = "Status"
    static let timestamp = "Timestamp"
    static let timeslot = "Timeslot"
    static let endTime = "EndTime"
    static let startTime = "StartTime"
    static let priority = "Priority"
    static let project = "DB_PROJECT"
    static let type = "Type"
    static let noteType = "NoteType"
    static let articleGenre = "ArticleGenre"
    static let permanentTags = "PermanentTags"
    static let deadline = "Deadline"
    static let spaceName = "Space Name"
    static let url = "URL"
  }
}

extension NotionPropertyValue {
  fileprivate var plainText: String? {
    switch rawValue {
    case .array(let array):
      let parts = array.compactMap { element -> String? in
        guard case .object(let object) = element,
          case .string(let text)? = object["plain_text"]
        else { return nil }
        return text
      }
      return parts.isEmpty ? nil : parts.joined(separator: "\n")
    case .string(let string):
      return string
    case .object(let object):
      if case .string(let text)? = object["plain_text"] {
        return text
      }
      return nil
    default:
      return nil
    }
  }

  fileprivate var statusValue: String? {
    guard case .object(let object) = rawValue,
      case .string(let name)? = object["name"]
    else { return nil }
    return name
  }

  fileprivate var selectValue: String? {
    guard case .object(let object) = rawValue,
      case .string(let name)? = object["name"]
    else { return nil }
    return name
  }

  fileprivate var multiSelectNames: [String] {
    guard case .array(let array) = rawValue else { return [] }
    return array.compactMap { element in
      guard case .object(let object) = element,
        case .string(let name)? = object["name"]
      else { return nil }
      return name
    }
  }

  fileprivate var relationIDs: [String] {
    guard case .array(let array) = rawValue else { return [] }
    return array.compactMap { element in
      guard case .object(let object) = element,
        case .string(let id)? = object["id"]
      else { return nil }
      return id
    }
  }

  fileprivate var urlValue: URL? {
    guard case .string(let string) = rawValue else { return nil }
    return URL(string: string)
  }
}
