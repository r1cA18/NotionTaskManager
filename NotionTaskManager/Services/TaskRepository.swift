import Combine
import Foundation
import SwiftData
import SwiftUI

enum TaskScope: CaseIterable {
  case inbox
  case todayTodo
  case todayCompleted
  case inProgress
  case overdue
}

@MainActor
protocol TaskRepositoryProtocol {
  func fetchTasks(for scope: TaskScope, on date: Date) throws -> [TaskEntity]
  func upsert(snapshots: [TaskSnapshot]) throws
  func startTask(_ task: TaskEntity, startedAt: Date) throws
  func completeTask(_ task: TaskEntity, completedAt: Date) throws
  func cancelTask(_ task: TaskEntity) throws
  func update(taskID: String, apply changes: (TaskEntity) -> Void) throws
  func remove(taskID: String) throws
  func task(withID id: String) throws -> TaskEntity?
  func pruneTasks(matching predicate: @escaping (TaskEntity) -> Bool, keepingIDs ids: Set<String>) throws
  func snapshot(taskID: String) throws -> TaskSnapshot?
  func overwrite(taskID: String, with snapshot: TaskSnapshot) throws
}

@MainActor
final class TaskRepository: TaskRepositoryProtocol, ObservableObject {
  private let context: ModelContext

  init(context: ModelContext) {
    self.context = context
  }

  func fetchTasks(for scope: TaskScope, on date: Date) throws -> [TaskEntity] {
    let descriptor = FetchDescriptor<TaskEntity>()
    let tasks = try context.fetch(descriptor).filter { $0.type != .trash }
    let boundaries = DateBoundaries(target: date)

    #if DEBUG
      debugPrint("[TaskRepository] 📊 Total tasks in DB: \(tasks.count)")
      debugPrint("[TaskRepository] 📅 Today range: \(boundaries.startOfDay) ~ \(boundaries.startOfTomorrow)")
    #endif

    let filtered = tasks.filter { task in
      TaskScopeMatcher.matches(task, scope: scope, on: date, boundaries: boundaries)
    }

    #if DEBUG
      debugPrint("[TaskRepository] \(scope) filtered count: \(filtered.count)")
    #endif

    switch scope {
    case .inbox:
      return filtered.sorted { $0.createdAt < $1.createdAt }
    case .todayTodo:
      return filtered.sorted { priorityScore(for: $0.priority) > priorityScore(for: $1.priority) }
    case .todayCompleted:
      return filtered.sorted { ($0.endTime ?? .distantPast) > ($1.endTime ?? .distantPast) }
    case .inProgress:
      return filtered.sorted { ($0.startTime ?? .distantPast) < ($1.startTime ?? .distantPast) }
    case .overdue:
      return filtered.sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
    }
  }

  func upsert(snapshots: [TaskSnapshot]) throws {
    for snapshot in snapshots {
      if let existing = try existingTask(for: snapshot.notionID) {
        apply(snapshot: snapshot, to: existing)
      } else {
        let task = TaskEntity(
          notionID: snapshot.notionID,
          name: snapshot.name,
          memo: snapshot.memo,
          status: snapshot.status,
          timestamp: snapshot.timestamp,
          timeslot: snapshot.timeslot,
          endTime: snapshot.endTime,
          startTime: snapshot.startTime,
          priority: snapshot.priority,
          projectIDs: snapshot.projectIDs,
          type: snapshot.type,
          noteType: snapshot.noteType,
          articleGenres: snapshot.articleGenres,
          permanentTags: snapshot.permanentTags,
          deadline: snapshot.deadline,
          spaceName: snapshot.spaceName,
          url: snapshot.url,
          bookmarkURL: snapshot.bookmarkURL,
          updatedAt: snapshot.updatedAt,
          createdAt: snapshot.createdAt
        )
        context.insert(task)
      }
    }
    if context.hasChanges {
      try context.save()
    }
  }

  func startTask(_ task: TaskEntity, startedAt: Date) throws {
    task.status = .inProgress
    task.startTime = startedAt
    if context.hasChanges {
      try context.save()
    }
  }

  func completeTask(_ task: TaskEntity, completedAt: Date) throws {
    task.status = .complete
    task.endTime = completedAt
    task.timestamp = normalizedDay(for: completedAt)
    if context.hasChanges {
      try context.save()
    }
  }

  func cancelTask(_ task: TaskEntity) throws {
    task.status = .toDo
    task.startTime = nil
    task.endTime = nil
    if context.hasChanges {
      try context.save()
    }
  }

  private func existingTask(for id: String) throws -> TaskEntity? {
    var descriptor = FetchDescriptor<TaskEntity>(
      predicate: #Predicate<TaskEntity> { task in
        task.notionID == id
      })
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
  }

  func update(taskID: String, apply changes: (TaskEntity) -> Void) throws {
    guard let entity = try existingTask(for: taskID) else { return }
    changes(entity)
    if context.hasChanges {
      try context.save()
    }
  }

  func remove(taskID: String) throws {
    guard let entity = try existingTask(for: taskID) else { return }
    context.delete(entity)
    if context.hasChanges {
      try context.save()
    }
  }

  func task(withID id: String) throws -> TaskEntity? {
    try existingTask(for: id)
  }

  func pruneTasks(matching predicate: @escaping (TaskEntity) -> Bool, keepingIDs ids: Set<String>) throws {
    let descriptor = FetchDescriptor<TaskEntity>()
    let entities = try context.fetch(descriptor)
    for entity in entities where predicate(entity) && !ids.contains(entity.notionID) {
      context.delete(entity)
    }
    if context.hasChanges {
      try context.save()
    }
  }

  func snapshot(taskID: String) throws -> TaskSnapshot? {
    guard let entity = try existingTask(for: taskID) else { return nil }
    return TaskSnapshot(task: entity)
  }

  func overwrite(taskID: String, with snapshot: TaskSnapshot) throws {
    guard let entity = try existingTask(for: taskID) else { return }
    apply(snapshot: snapshot, to: entity)
    if context.hasChanges {
      try context.save()
    }
  }

  private func apply(snapshot: TaskSnapshot, to task: TaskEntity) {
    task.name = snapshot.name
    task.memo = snapshot.memo
    task.status = snapshot.status
    task.timestamp = snapshot.timestamp
    task.timeslot = snapshot.timeslot
    task.endTime = snapshot.endTime
    task.startTime = snapshot.startTime
    task.priority = snapshot.priority
    task.projectIDs = snapshot.projectIDs
    task.type = snapshot.type
    task.noteType = snapshot.noteType
    task.articleGenres = snapshot.articleGenres
    task.permanentTags = snapshot.permanentTags
    task.deadline = snapshot.deadline
    task.spaceName = snapshot.spaceName
    task.url = snapshot.url
    task.bookmarkURL = snapshot.bookmarkURL
    task.updatedAt = snapshot.updatedAt
    task.createdAt = snapshot.createdAt
  }

  private func priorityScore(for priority: TaskPriority?) -> Int {
    switch priority {
    case .fourStars: return 4
    case .threeAndHalf: return 3
    case .twoStars: return 2
    case .oneStar: return 1
    case .none: return 0
    }
  }

  private func normalizedDay(for date: Date) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .tokyo
    return calendar.startOfDay(for: date)
  }
}
