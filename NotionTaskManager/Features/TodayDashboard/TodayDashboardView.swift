import Combine
import SwiftUI

struct TodayDashboardView: View {
    private let repository: TaskRepositoryProtocol
    private let syncService: TaskSyncService?
    @StateObject private var viewModel: TodayDashboardViewModel
    @State private var targetDate: Date = Date()
    @State private var showingInbox = false
    @State private var showingOverdue = false
    @State private var showingSyncError = false
    @State private var syncErrorMessage = ""
    @State private var activeTab: TodayTab = .todo
    @State private var editingTask: TaskDisplayModel?

    init(repository: TaskRepositoryProtocol, syncService: TaskSyncService? = nil) {
        self.repository = repository
        self.syncService = syncService
        _viewModel = StateObject(
            wrappedValue: TodayDashboardViewModel(repository: repository, syncService: syncService))
    }

    var body: some View {
        VStack(spacing: 16) {
            Picker("表示", selection: $activeTab) {
                ForEach(TodayTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.top, 16)
            .padding(.horizontal, 20)

            TabView(selection: $activeTab) {
                todoPage
                    .tag(TodayTab.todo)
                completedPage
                    .tag(TodayTab.completed)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground))
        .task(id: targetDate) {
            await viewModel.refresh(for: targetDate)
        }
        .overlay(alignment: .bottom) {
            inProgressPill
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
        .overlay(alignment: .bottomTrailing) {
            VStack(spacing: 16) {
                if viewModel.hasOverdueTasks {
                    floatingButton(
                        systemImage: "clock.arrow.circlepath",
                        color: .red,
                        accessibilityLabel: "Overdueを開く"
                    ) { showingOverdue = true }
                }
                if viewModel.hasInboxTasks {
                    floatingButton(
                        systemImage: "tray.full",
                        color: .accentColor,
                        accessibilityLabel: "Inboxを開く"
                    ) { showingInbox = true }
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showingInbox) {
            if let syncService {
                InboxCarouselView(
                    viewModel: InboxCarouselViewModel(
                        repository: repository,
                        syncService: syncService,
                        initialTasks: viewModel.inboxTasks
                    )
                )
            } else {
                Text("Inboxプレビューは無効です")
                    .padding()
            }
        }
        .sheet(isPresented: $showingOverdue) {
            if let syncService {
                OverdueCarouselView(
                    viewModel: OverdueCarouselViewModel(
                        repository: repository,
                        syncService: syncService,
                        initialTasks: viewModel.overdueTasks
                    )
                )
            } else {
                Text("Overdueプレビューは無効です")
                    .padding()
            }
        }
        .sheet(item: $editingTask) { task in
            TaskDetailEditor(task: task) { changes in
                Task { await viewModel.applyEdits(changes, to: task, on: targetDate) }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if viewModel.isLoading {
                    ProgressView().progressViewStyle(.circular)
                } else {
                    Button {
                        Task { await refreshToday() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh tasks")
                }
            }
        }
        .onReceive(viewModel.$lastError) { error in
            DispatchQueue.main.async {
                syncErrorMessage = error ?? ""
                showingSyncError = error != nil
            }
        }
        .alert("同期エラー", isPresented: $showingSyncError) {
            Button("閉じる", role: .cancel) {
                showingSyncError = false
                Task { @MainActor in viewModel.lastError = nil }
            }
        } message: {
            Text(syncErrorMessage)
        }
    }

    private var todoPage: some View {
        buildPage {
            todoSection
        }
    }

    private var completedPage: some View {
        buildPage {
            completedSection
        }
    }

    private func buildPage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                content()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 180)
        }
        .refreshable {
            await refreshToday()
        }
    }

    private func refreshToday() async {
        let now = Date()
        await MainActor.run {
            targetDate = now
        }
        await viewModel.refresh(for: now)
    }

    private var todoSection: some View {
        SectionContainer(
            title: "今日のタスク",
            subtitle: "Status = To Do",
            tint: TaskPalette.todoBackground,
            foreground: TaskPalette.todoForeground
        ) {
            if viewModel.todoGroups.isEmpty {
                EmptyLabel(text: "予定されているタスクはありません")
            } else {
                VStack(spacing: 16) {
                    ForEach(Array(viewModel.todoGroups.enumerated()), id: \.offset) { _, group in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(group.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(group.tint.opacity(0.35), in: Capsule())
                            VStack(spacing: 12) {
                                ForEach(group.tasks) { model in
                                    TodoCard(
                                        model: model,
                                        tint: group.tint,
                                        onStart: {
                                            Task { await viewModel.startTask(model, on: targetDate) }
                                        },
                                        onTrash: {
                                            Task { await viewModel.trashTask(model, on: targetDate) }
                                        },
                                        onTap: {
                                            editingTask = model
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func floatingButton(
        systemImage: String,
        color: Color,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.white)
                .padding()
                .background(Circle().fill(color))
                .shadow(radius: 4)
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var completedSection: some View {
        SectionContainer(
            title: "完了したタスク",
            subtitle: "最新順",
            tint: TaskPalette.completedBackground,
            foreground: TaskPalette.completedForeground
        ) {
            if viewModel.completedToday.isEmpty {
                EmptyLabel(text: "まだ完了したタスクはありません")
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.completedToday) { model in
                        CompletedCard(
                            model: model,
                            onTap: {
                                editingTask = model
                            }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var inProgressPill: some View {
        if viewModel.inProgress.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 12) {
                ForEach(viewModel.inProgress) { model in
                    SwipeableInProgressRow(
                        model: model,
                        onComplete: {
                            Task { await viewModel.completeTask(model, on: targetDate) }
                        },
                        onCancel: {
                            Task { await viewModel.cancelTask(model, on: targetDate) }
                        },
                        onTap: {
                            editingTask = model
                        }
                    )
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

private enum TodayTab: Int, CaseIterable, Identifiable {
    case todo
    case completed

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .todo: return "To Do"
        case .completed: return "Complete"
        }
    }
}

#Preview {
    TodayDashboardView(repository: PreviewTaskRepository(), syncService: nil)
        .padding()
        .background(Color(.systemGroupedBackground))
}

private final class PreviewTaskRepository: TaskRepositoryProtocol {
    private var storage: [String: TaskEntity] = [:]

    func fetchTasks(for scope: TaskScope, on date: Date) throws -> [TaskEntity] {
        let tasks: [TaskEntity]
        switch scope {
        case .todayTodo:
            tasks = [
                sampleTask(
                    id: "A", title: "Inbox Task", status: .toDo, baseDate: date, timestampOffset: 0,
                    endOffset: nil, priority: .fourStars, timeslot: .morning, noteType: nil)
            ]
        case .todayCompleted:
            tasks = [
                sampleTask(
                    id: "B", title: "Finished Task", status: .complete, baseDate: date, timestampOffset: 0,
                    endOffset: 600, priority: .threeAndHalf, timeslot: .evening, noteType: nil)
            ]
        case .inProgress:
            tasks = [
                sampleTask(
                    id: "C", title: "In Progress", status: .inProgress, baseDate: date, timestampOffset: 0,
                    endOffset: nil, priority: .twoStars, timeslot: .afternoon, startOffset: -300,
                    noteType: nil)
            ]
        case .inbox:
            tasks = [
                sampleTask(
                    id: "D", title: "Inbox Preview", status: .toDo, baseDate: date, timestampOffset: 0,
                    endOffset: nil, priority: .twoStars, timeslot: nil, noteType: nil)
            ]
        case .overdue:
            tasks = [
                sampleTask(
                    id: "E", title: "Overdue Task", status: .toDo, baseDate: date.addingTimeInterval(-86_400),
                    timestampOffset: -86_400, endOffset: nil, priority: .oneStar, timeslot: nil,
                    noteType: nil, deadlineOffset: -86_400)
            ]
        }
        tasks.forEach { storage[$0.notionID] = $0 }
        return tasks
    }

    func upsert(snapshots: [TaskSnapshot]) throws {
        for snapshot in snapshots {
            storage[snapshot.notionID] = TaskEntity(
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
        }
    }

    func startTask(_ task: TaskEntity, startedAt: Date) throws {
        task.status = .inProgress
        task.startTime = startedAt
    }

    func completeTask(_ task: TaskEntity, completedAt: Date) throws {
        task.status = .complete
        task.endTime = completedAt
    }

    func cancelTask(_ task: TaskEntity) throws {
        task.status = .toDo
        task.startTime = nil
    }

    func update(taskID: String, apply changes: (TaskEntity) -> Void) throws {
        guard let task = storage[taskID] else { return }
        changes(task)
    }

    func remove(taskID: String) throws {
        storage.removeValue(forKey: taskID)
    }

    func task(withID id: String) throws -> TaskEntity? {
        storage[id]
    }

    func pruneTasks(matching predicate: @escaping (TaskEntity) -> Bool, keepingIDs ids: Set<String>)
        throws
    {
        storage = storage.filter { key, value in
            guard predicate(value) else { return true }
            return ids.contains(key)
        }
    }

    func snapshot(taskID: String) throws -> TaskSnapshot? {
        guard let task = storage[taskID] else { return nil }
        return TaskSnapshot(task: task)
    }

    func overwrite(taskID: String, with snapshot: TaskSnapshot) throws {
        storage[taskID] = TaskEntity(
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
    }

    private func sampleTask(
        id: String,
        title: String,
        status: TaskStatus,
        baseDate: Date,
        timestampOffset: TimeInterval,
        endOffset: TimeInterval?,
        priority: TaskPriority?,
        timeslot: TaskTimeslot? = nil,
        startOffset: TimeInterval? = nil,
        noteType: String? = nil,
        deadlineOffset: TimeInterval? = nil
    ) -> TaskEntity {
        TaskEntity(
            notionID: id,
            name: title,
            status: status,
            timestamp: baseDate.addingTimeInterval(timestampOffset),
            timeslot: timeslot,
            endTime: endOffset.map { baseDate.addingTimeInterval($0) },
            startTime: startOffset.map { baseDate.addingTimeInterval($0) },
            priority: priority,
            projectIDs: [],
            type: nil,
            noteType: noteType,
            articleGenres: [],
            permanentTags: [],
            deadline: deadlineOffset.map { baseDate.addingTimeInterval($0) },
            spaceName: nil,
            url: nil,
            bookmarkURL: nil,
            updatedAt: .now,
            createdAt: .now
        )
    }
}
