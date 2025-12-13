import SwiftUI

/// Main view for date-based task navigation with Liquid Glass design
struct DateNavigationView: View {
    private let repository: TaskRepositoryProtocol
    private let syncService: TaskSyncService?
    @StateObject private var viewModel: DateNavigationViewModel
    
    @State private var showingCalendar = false
    @State private var showingInbox = false
    @State private var showingOverdue = false
    @State private var showingSyncError = false
    @State private var syncErrorMessage = ""
    @State private var activeTab: TaskTab = .todo
    @State private var editingTask: TaskDisplayModel?
    
    @Namespace private var animation
    
    init(repository: TaskRepositoryProtocol, syncService: TaskSyncService? = nil) {
        self.repository = repository
        self.syncService = syncService
        _viewModel = StateObject(
            wrappedValue: DateNavigationViewModel(
                repository: repository,
                syncService: syncService
            )
        )
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background gradient
            backgroundGradient
                .ignoresSafeArea()
            
            // Main content
            VStack(spacing: 0) {
                // Compact header with date
                headerSection
                
                // Date selector
                dateSelector
                
                // Task content area
                taskContentArea
            }
            
            // Bottom floating elements
            VStack(spacing: 0) {
                // In-progress tasks
                if !viewModel.inProgressTasks.isEmpty {
                    inProgressSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Bottom action bar
                bottomActionBar
            }
        }
        .task {
            await viewModel.initialLoad()
        }
        .sheet(isPresented: $showingCalendar) {
            CalendarPopupView(
                selectedDate: $viewModel.selectedDate,
                onDateSelected: { date in
                    Task { await viewModel.selectDate(date) }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingInbox) {
            inboxSheet
        }
        .sheet(isPresented: $showingOverdue) {
            overdueSheet
        }
        .sheet(item: $editingTask) { task in
            TaskDetailEditor(task: task) { changes in
                Task { await viewModel.applyEdits(changes, to: task) }
            }
        }
        .onReceive(viewModel.$lastError) { error in
            handleError(error)
        }
        .alert("同期エラー", isPresented: $showingSyncError) {
            Button("再試行") {
                showingSyncError = false
                Task {
                    viewModel.lastError = nil
                    await viewModel.refreshTasks()
                }
            }
            Button("閉じる", role: .cancel) {
                showingSyncError = false
                viewModel.lastError = nil
            }
        } message: {
            Text(syncErrorMessage)
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        ZStack {
            Color(.systemBackground)
            
            // Subtle gradient overlay
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.05),
                    Color.purple.opacity(0.03),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(alignment: .center, spacing: 16) {
            // Date button
            Button {
                showingCalendar = true
            } label: {
                HStack(spacing: 10) {
                    // Day number
                    Text(dayNumber)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(weekdayString)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(monthYearString)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Today button (when not on today)
            if !isToday {
                Button {
                    goToToday()
                } label: {
                    Text("今日")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.accentColor)
                        )
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // Refresh/Settings
            HStack(spacing: 4) {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button {
                        Task { await viewModel.refreshTasks() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, height: 40)
                    }
                }
                
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 40, height: 40)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .animation(.spring(response: 0.3), value: isToday)
    }
    
    // MARK: - Date Selector
    
    private var dateSelector: some View {
        DateSelectorView(
            selectedDate: $viewModel.selectedDate,
            onDateChanged: { date in
                Task { await viewModel.selectDate(date) }
            }
        )
        .padding(.bottom, 8)
    }
    
    // MARK: - Task Content Area
    
    private var taskContentArea: some View {
        VStack(spacing: 0) {
            // Tab picker
            tabPicker
                .padding(.horizontal, 20)
                .padding(.top, 16)
            
            // Task list
            TabView(selection: $activeTab) {
                todoPage.tag(TaskTab.todo)
                completedPage.tag(TaskTab.completed)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: -8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
    
    private var tabPicker: some View {
        HStack(spacing: 4) {
            ForEach(TaskTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        activeTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14, weight: .medium))
                        Text(tab.title)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(activeTab == tab ? .white : .secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background {
                        if activeTab == tab {
                            Capsule()
                                .fill(Color.accentColor)
                                .matchedGeometryEffect(id: "tab", in: animation)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color(.systemFill).opacity(0.5))
        )
    }
    
    // MARK: - Pages
    
    private var todoPage: some View {
        buildPage {
            if viewModel.todoGroups.isEmpty {
                emptyState(
                    icon: "tray",
                    title: "タスクがありません",
                    subtitle: "今日予定されているタスクはありません"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(viewModel.todoGroups.enumerated()), id: \.offset) { _, group in
                        timeslotSection(group: group)
                    }
                }
            }
        }
    }
    
    private var completedPage: some View {
        buildPage {
            if viewModel.completedTasks.isEmpty {
                emptyState(
                    icon: "checkmark.circle",
                    title: "完了タスクなし",
                    subtitle: "タスクを完了するとここに表示されます"
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.completedTasks) { model in
                        CompletedCard(
                            model: model,
                            onTap: { editingTask = model }
                        )
                    }
                }
            }
        }
    }
    
    private func buildPage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Sync indicator
                if viewModel.isLoading && !viewModel.isInitialLoad {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("同期中...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                content()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 200) // Space for bottom UI
        }
        .refreshable {
            await viewModel.refreshTasks()
        }
    }
    
    // MARK: - Timeslot Section
    
    private func timeslotSection(group: (slot: TaskTimeslot?, title: String, tint: Color, tasks: [TaskDisplayModel])) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack(spacing: 8) {
                Circle()
                    .fill(TaskPalette.accentColor(for: group.slot))
                    .frame(width: 8, height: 8)
                
                Text(group.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                Text("\(group.tasks.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color(.systemFill))
                    )
            }
            .padding(.leading, 4)
            
            // Task cards
            VStack(spacing: 10) {
                ForEach(group.tasks) { model in
                    TodoCard(
                        model: model,
                        tint: TaskPalette.accentColor(for: group.slot),
                        isSyncing: viewModel.isTaskSyncing(model.id),
                        onStart: {
                            Task { await viewModel.startTask(model) }
                        },
                        onTrash: {
                            Task { await viewModel.trashTask(model) }
                        },
                        onTap: { editingTask = model }
                    )
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - In Progress Section
    
    private var inProgressSection: some View {
        VStack(spacing: 10) {
            ForEach(viewModel.inProgressTasks) { model in
                SwipeableInProgressRow(
                    model: model,
                    isSyncing: viewModel.isTaskSyncing(model.id),
                    onComplete: {
                        Task { await viewModel.completeTask(model) }
                    },
                    onCancel: {
                        Task { await viewModel.cancelTask(model) }
                    },
                    onTap: { editingTask = model }
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
    
    // MARK: - Bottom Action Bar
    
    private var bottomActionBar: some View {
        HStack(spacing: 16) {
            // Overdue button
            if viewModel.hasOverdueTasks {
                actionButton(
                    icon: "clock.badge.exclamationmark",
                    label: "期限切れ",
                    badge: viewModel.overdueTasks.count,
                    tint: .red
                ) {
                    showingOverdue = true
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            Spacer()
            
            // Inbox button
            if viewModel.hasInboxTasks {
                actionButton(
                    icon: "tray.full",
                    label: "Inbox",
                    badge: viewModel.inboxTasks.count,
                    tint: .accentColor
                ) {
                    showingInbox = true
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: -10)
        )
        .animation(.spring(response: 0.4), value: viewModel.hasInboxTasks)
        .animation(.spring(response: 0.4), value: viewModel.hasOverdueTasks)
    }
    
    private func actionButton(
        icon: String,
        label: String,
        badge: Int,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [tint, tint.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                    
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.red)
                            )
                            .offset(x: 6, y: -6)
                    }
                }
                
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.trailing, 16)
            .padding(.leading, 4)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helpers
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        formatter.timeZone = .tokyo
        return formatter.string(from: viewModel.selectedDate)
    }
    
    private var weekdayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.timeZone = .tokyo
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: viewModel.selectedDate)
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年 M月"
        formatter.timeZone = .tokyo
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: viewModel.selectedDate)
    }
    
    private var isToday: Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .tokyo
        return calendar.isDateInToday(viewModel.selectedDate)
    }
    
    private func goToToday() {
        let today = Date.todayInJST()
        Task { await viewModel.selectDate(today) }
    }
    
    private func handleError(_ error: String?) {
        guard let error = error, !error.isEmpty else { return }
        syncErrorMessage = error
        showingSyncError = true
    }
    
    // MARK: - Sheets
    
    @ViewBuilder
    private var inboxSheet: some View {
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
    
    @ViewBuilder
    private var overdueSheet: some View {
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
}

// MARK: - Task Tab

private enum TaskTab: Int, CaseIterable, Identifiable {
    case todo
    case completed
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .todo: return "To Do"
        case .completed: return "完了"
        }
    }
    
    var icon: String {
        switch self {
        case .todo: return "circle"
        case .completed: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    DateNavigationView(repository: PreviewTaskRepository(), syncService: nil)
}

private final class PreviewTaskRepository: TaskRepositoryProtocol {
    private var storage: [String: TaskEntity] = [:]
    
    func fetchTasks(for scope: TaskScope, on date: Date) throws -> [TaskEntity] {
        let tasks: [TaskEntity]
        switch scope {
        case .todayTodo:
            tasks = [
                sampleTask(id: "A", title: "朝の会議準備", status: .toDo, baseDate: date,
                          priority: .fourStars, timeslot: .morning),
                sampleTask(id: "B", title: "デザインレビュー", status: .toDo, baseDate: date,
                          priority: .threeAndHalf, timeslot: .afternoon),
            ]
        case .todayCompleted:
            tasks = [
                sampleTask(id: "C", title: "メール確認", status: .complete, baseDate: date,
                          priority: .twoStars, timeslot: .morning, endOffset: 600),
            ]
        case .inProgress:
            tasks = []
        case .inbox:
            tasks = []
        case .overdue:
            tasks = []
        }
        tasks.forEach { storage[$0.notionID] = $0 }
        return tasks
    }
    
    func upsert(snapshots: [TaskSnapshot]) throws {}
    func startTask(_ task: TaskEntity, startedAt: Date) throws {}
    func completeTask(_ task: TaskEntity, completedAt: Date) throws {}
    func cancelTask(_ task: TaskEntity) throws {}
    func update(taskID: String, apply changes: (TaskEntity) -> Void) throws {}
    func remove(taskID: String) throws {}
    func task(withID id: String) throws -> TaskEntity? { storage[id] }
    func pruneTasks(matching predicate: @escaping (TaskEntity) -> Bool, keepingIDs ids: Set<String>) throws {}
    func snapshot(taskID: String) throws -> TaskSnapshot? { nil }
    func overwrite(taskID: String, with snapshot: TaskSnapshot) throws {}
    
    private func sampleTask(
        id: String, title: String, status: TaskStatus, baseDate: Date,
        priority: TaskPriority?, timeslot: TaskTimeslot? = nil,
        endOffset: TimeInterval? = nil
    ) -> TaskEntity {
        TaskEntity(
            notionID: id, name: title, status: status,
            timestamp: baseDate,
            timeslot: timeslot,
            endTime: endOffset.map { baseDate.addingTimeInterval($0) },
            priority: priority, projectIDs: [], type: nil,
            articleGenres: [], permanentTags: [],
            updatedAt: .now, createdAt: .now
        )
    }
}
