import Combine
import Foundation

@MainActor
final class TaskSyncService: ObservableObject {
  @Published private(set) var isSyncing = false
  @Published private(set) var lastError: String?

  private let dependencies: AppDependencies
  private let repository: TaskRepositoryProtocol
  private let client: NotionClientProtocol
  private let mapper: NotionTaskMapper

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
  }

  func refresh(for date: Date) async {
    if isSyncing {
      while isSyncing {
        if Task.isCancelled { return }
        await Task.yield()
      }
    }

    guard let credentials = dependencies.currentCredentials() else {
      lastError = "Missing Notion credentials."
      return
    }

    isSyncing = true
    defer { isSyncing = false }

    let dayString = Self.dayFormatter.string(from: date)
    log("[TaskSyncService] 🔍 Fetching tasks for date: \(dayString)")

    do {
      var cursor: String?
      var snapshots: [TaskSnapshot] = []

      let filter = TaskScopeMatcher.combinedDailyFilter(dayString: dayString)

      repeat {
        let request = NotionDatabaseQueryRequest(filter: filter, pageSize: 100, startCursor: cursor)
        let response = try await client.queryDatabase(credentials: credentials, request: request)
        var mapped = response.results.compactMap(mapper.snapshot(from:))
        for index in mapped.indices {
          guard mapped[index].bookmarkURL == nil else { continue }
          do {
            log(
              "[NotionSync] 🔍 Fetching bookmark for page: \(mapped[index].notionID) (\(mapped[index].name))"
            )
            if let bookmark = try await client.firstBookmarkURL(
              credentials: credentials, pageID: mapped[index].notionID)
            {
              log("[NotionSync] ✅ Found bookmark: \(bookmark.absoluteString)")
              mapped[index].bookmarkURL = bookmark
            } else {
              log("[NotionSync] ℹ️ No bookmark found for page: \(mapped[index].name)")
            }
          } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled {
              log("[NotionSync] ⏩ Bookmark fetch cancelled for \(mapped[index].notionID)")
            } else {
              log("[NotionSync] ⚠️ Bookmark fetch failed for \(mapped[index].notionID): \(error)")
            }
          }
        }
        snapshots.append(contentsOf: mapped)
        cursor = response.hasMore ? response.nextCursor : nil
      } while cursor != nil

      try repository.upsert(snapshots: snapshots)
      let ids = Set(snapshots.map(\.notionID))
      try repository.pruneTasks(
        matching: { entity in
          entity.isInboxCandidate
            || entity.isOverdueCandidate
            || self.isSameDay(entity.timestamp, comparedTo: date)
            || self.isSameDay(entity.startTime, comparedTo: date)
            || self.isSameDay(entity.endTime, comparedTo: date)
        },
        keepingIDs: ids)
      lastError = nil
    } catch is CancellationError {
      lastError = nil
      log("[NotionSync] 🔄 Refresh cancelled (view disposed)")
    } catch let error as URLError where error.code == .cancelled {
      lastError = nil
      log("[NotionSync] 🔄 URLSession cancelled request")
    } catch let error as NotionClientError {
      lastError = error.localizedDescription
      log("[NotionSync] NotionClientError \(error)")
    } catch {
      lastError = error.localizedDescription
      log("[NotionSync] Unexpected error \(error)")
    }
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

    do {
      try repository.startTask(entity, startedAt: startedAt)
      lastError = nil
    } catch {
      lastError = error.localizedDescription
      log("[NotionSync] ❌ Local start mutation failed: \(error)")
      return
    }

    enqueueMutation(
      taskID: taskID,
      previousSnapshot: snapshot,
      credentials: credentials
    ) { credentials in
      // まずアーカイブを解除
      let unarchiveRequest = NotionPageUpdateRequest(
        properties: [:],
        archived: false
      )
      _ = try await self.client.updatePage(
        credentials: credentials,
        pageID: taskID,
        request: unarchiveRequest
      )

      // その後にプロパティを更新
      let request = NotionPageUpdateRequest(
        properties: self.patchProperties(
          status: .inProgress,
          start: .set(startedAt),
          end: .ignore,
          timestamp: needsTimestamp ? .set(startedAt) : .ignore
        ))
      _ = try await self.client.updatePage(
        credentials: credentials,
        pageID: taskID,
        request: request
      )
    }
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

    do {
      try repository.completeTask(entity, completedAt: completedAt)
      lastError = nil
    } catch {
      lastError = error.localizedDescription
      log("[NotionSync] ❌ Local complete mutation failed: \(error)")
      return
    }

    enqueueMutation(
      taskID: taskID,
      previousSnapshot: snapshot,
      credentials: credentials
    ) { credentials in
      // まずアーカイブを解除（既にアーカイブされてる可能性があるため）
      let unarchiveRequest = NotionPageUpdateRequest(
        properties: [:],
        archived: false
      )
      _ = try await self.client.updatePage(
        credentials: credentials,
        pageID: taskID,
        request: unarchiveRequest
      )

      // その後にプロパティを更新
      let request = NotionPageUpdateRequest(
        properties: self.patchProperties(
          status: .complete,
          start: .ignore,
          end: .set(completedAt),
          timestamp: .set(completionDay)
        ))
      _ = try await self.client.updatePage(
        credentials: credentials,
        pageID: taskID,
        request: request
      )
    }
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

    let request = NotionPageUpdateRequest(
      properties: patchProperties(
        status: .toDo,
        start: .clear,
        end: .clear,
        timestamp: .ignore
      ))

    do {
      try repository.cancelTask(entity)
      lastError = nil
    } catch {
      lastError = error.localizedDescription
      log("[NotionSync] ❌ Local cancel mutation failed: \(error)")
      return
    }

    enqueueMutation(
      taskID: taskID,
      previousSnapshot: snapshot,
      credentials: credentials
    ) { credentials in
      // まずアーカイブを解除
      let unarchiveRequest = NotionPageUpdateRequest(
        properties: [:],
        archived: false
      )
      _ = try await self.client.updatePage(
        credentials: credentials,
        pageID: taskID,
        request: unarchiveRequest
      )

      // その後にプロパティを更新
      _ = try await self.client.updatePage(
        credentials: credentials,
        pageID: taskID,
        request: request
      )
    }
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

    do {
      try repository.update(taskID: taskID) { entity in
        entity.type = .trash
        entity.status = .toDo
      }
      lastError = nil
    } catch {
      lastError = error.localizedDescription
      log("[NotionSync] ❌ Local trash mutation failed: \(error)")
      return
    }

    enqueueMutation(
      taskID: taskID,
      previousSnapshot: snapshot,
      credentials: credentials
    ) { credentials in
      // まずアーカイブを解除（既にアーカイブされてる可能性があるため）
      let unarchiveRequest = NotionPageUpdateRequest(
        properties: [:],
        archived: false
      )
      _ = try await self.client.updatePage(
        credentials: credentials,
        pageID: taskID,
        request: unarchiveRequest
      )

      // その後にプロパティを更新
      let request = NotionPageUpdateRequest(
        properties: [
          "Type": self.selectProperty(name: TaskType.trash.rawValue),
          "Status": self.statusProperty(.toDo),
        ]
      )
      _ = try await self.client.updatePage(
        credentials: credentials,
        pageID: taskID,
        request: request
      )
    }
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

    do {
      try repository.update(taskID: taskID) { entity in
        entity.type = .nextAction
        entity.status = .toDo
        if shouldUpdateTimestamp {
          entity.timestamp = today
        }
      }
      lastError = nil
    } catch {
      lastError = error.localizedDescription
      log("[NotionSync] ❌ Local convert mutation failed: \(error)")
      return
    }

    enqueueMutation(
      taskID: taskID,
      previousSnapshot: snapshot,
      credentials: credentials
    ) { credentials in
      // まずアーカイブを解除
      let unarchiveRequest = NotionPageUpdateRequest(
        properties: [:],
        archived: false
      )
      _ = try await self.client.updatePage(
        credentials: credentials,
        pageID: taskID,
        request: unarchiveRequest
      )

      // その後にプロパティを更新
      var properties: [String: JSONValue] = [
        "Type": self.selectProperty(name: TaskType.nextAction.rawValue),
        "Status": self.statusProperty(.toDo),
      ]
      if shouldUpdateTimestamp {
        properties["Timestamp"] = self.timestampProperty(from: today)
      }
      let request = NotionPageUpdateRequest(properties: properties)
      _ = try await self.client.updatePage(
        credentials: credentials, pageID: taskID, request: request)
    }
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

    do {
      try repository.update(taskID: taskID) { entity in
        changes.apply(to: entity)
      }
      lastError = nil
    } catch {
      lastError = error.localizedDescription
      log("[NotionSync] ❌ Local update mutation failed: \(error)")
      return
    }

    enqueueMutation(
      taskID: taskID,
      previousSnapshot: snapshot,
      credentials: credentials
    ) { credentials in
      // まずアーカイブを解除
      let unarchiveRequest = NotionPageUpdateRequest(
        properties: [:],
        archived: false
      )
      _ = try await self.client.updatePage(
        credentials: credentials,
        pageID: taskID,
        request: unarchiveRequest
      )

      // その後にプロパティを更新
      let request = NotionPageUpdateRequest(properties: properties)
      _ = try await self.client.updatePage(
        credentials: credentials,
        pageID: taskID,
        request: request
      )
    }
  }

  private func enqueueMutation(
    taskID: String,
    previousSnapshot: TaskSnapshot,
    credentials: NotionCredentials,
    performRemote: @escaping (NotionCredentials) async throws -> Void
  ) {
    Task.detached { [weak self] in
      guard let self else { return }
      do {
        try await performRemote(credentials)
        await MainActor.run {
          self.lastError = nil
        }
      } catch {
        await self.handleMutationFailure(taskID: taskID, snapshot: previousSnapshot, error: error)
      }
    }
  }

  private func handleMutationFailure(
    taskID: String,
    snapshot: TaskSnapshot,
    error: Error
  ) async {
    await MainActor.run {
      self.log("[NotionSync] ❌ Remote mutation failed for \(taskID): \(error)")
      do {
        try self.repository.overwrite(taskID: taskID, with: snapshot)
      } catch {
        self.log("[NotionSync] ❌ Failed to revert local state for \(taskID): \(error)")
      }
      self.lastError = self.describe(error)
    }
  }

  private func describe(_ error: Error) -> String {
    if let notionError = error as? NotionClientError {
      return notionError.localizedDescription
    }
    if let urlError = error as? URLError, urlError.code == .cancelled {
      return "Request was cancelled."
    }
    return error.localizedDescription
  }

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
    let textObject: JSONValue = .object(["type": .string("text"),
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
    case .clear:
      break
    case .unchanged:
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
    case .clear:
      break
    case .unchanged:
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

  private func log(_ message: String) {
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

  private static let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = .tokyo
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()
}
