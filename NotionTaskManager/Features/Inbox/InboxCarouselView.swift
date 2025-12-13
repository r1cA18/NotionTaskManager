import Combine
import SwiftUI

struct InboxCarouselView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: InboxCarouselViewModel
    @State private var showingEditor = false
    @State private var showingMandatorySheet = false
    @State private var pendingMandatoryTaskID: String?
    @State private var pendingMandatoryPriority: TaskPriority?
    @State private var pendingMandatoryTimeslot: TaskTimeslot?
    @State private var showingSyncError = false
    @State private var syncErrorMessage = ""
    @State private var pendingErrorMessage: String?
    @GestureState private var horizontalOffset: CGFloat = 0
    
    init(viewModel: InboxCarouselViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                backgroundGradient
                    .ignoresSafeArea()
                
                if let task = viewModel.currentTask {
                    cardView(for: task)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    emptyState
                }
            }
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button {
                            Task { await viewModel.refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.refresh()
            if !viewModel.hasTasks {
                dismiss()
            }
        }
        .onChange(of: viewModel.hasTasks) { _, hasTasks in
            if !hasTasks {
                dismiss()
            }
        }
        .onReceive(viewModel.$lastError) { handleError($0) }
        .alert("同期エラー", isPresented: $showingSyncError) {
            Button("閉じる", role: .cancel) {
                showingSyncError = false
                viewModel.lastError = nil
            }
        } message: {
            Text(syncErrorMessage)
        }
        .sheet(isPresented: $showingEditor, onDismiss: handleSheetDismiss) {
            if let task = viewModel.currentTask {
                TaskDetailEditor(task: task) { changes in
                    Task { await viewModel.applyEdits(changes) }
                }
            }
        }
        .sheet(isPresented: $showingMandatorySheet, onDismiss: handleSheetDismiss) {
            MandatoryFieldsSheet(
                initialPriority: pendingMandatoryPriority,
                initialTimeslot: pendingMandatoryTimeslot
            ) { priority, timeslot in
                showingMandatorySheet = false
                let pendingID = pendingMandatoryTaskID
                resetMandatoryState()
                guard let currentID = viewModel.currentTask?.id, currentID == pendingID else { return }
                Task { await viewModel.assignCurrent(priority: priority, timeslot: timeslot) }
            } onCancel: {
                showingMandatorySheet = false
                resetMandatoryState()
            }
        }
        .gesture(horizontalGesture)
        .simultaneousGesture(verticalDismissGesture)
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.05),
                    Color.purple.opacity(0.03),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 8) {
                Text("Inboxは空です")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                Text("新しいタスクがNotionへ追加されるとここに表示されます")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }
    
    // MARK: - Card View
    
    @ViewBuilder
    private func cardView(for task: TaskDisplayModel) -> some View {
        VStack(spacing: 0) {
            // Swipe hints
            swipeHints
            
            // Main card
            InboxCardView(
                task: task,
                tint: Color.blue,
                onSelectPriority: { priority in
                    Task { await viewModel.updatePriority(priority) }
                },
                onSelectTimeslot: { timeslot in
                    Task { await viewModel.updateTimeslot(timeslot) }
                },
                onSelectTimestamp: { date in
                    Task { await viewModel.updateTimestamp(to: date) }
                },
                onEdit: { showingEditor = true }
            )
            .offset(x: horizontalOffset)
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Queue indicator
            queueIndicator
        }
    }
    
    private var swipeHints: some View {
        HStack {
            if horizontalOffset > 20 {
                swipeLabel(icon: "tray.and.arrow.down.fill", text: "振り分け", color: .blue)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            Spacer()
            if horizontalOffset < -20 {
                swipeLabel(icon: "arrow.uturn.forward", text: "Next Action", color: .orange)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .animation(.spring(response: 0.25), value: horizontalOffset)
    }
    
    private func swipeLabel(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(text)
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    private var queueIndicator: some View {
        VStack(spacing: 8) {
            if viewModel.queue.count > 1 {
                Text("\(viewModel.queue.count) タスク残り")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 4) {
                    ForEach(0..<min(viewModel.queue.count, 5), id: \.self) { index in
                        Circle()
                            .fill(index == 0 ? Color.accentColor : Color(.systemFill))
                            .frame(width: 6, height: 6)
                    }
                    if viewModel.queue.count > 5 {
                        Text("+\(viewModel.queue.count - 5)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.bottom, 32)
    }
    
    // MARK: - Gestures
    
    private var horizontalGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .updating($horizontalOffset) { value, state, _ in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                state = value.translation.width * 0.8
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let translation = value.translation.width
                if translation > 120 {
                    handleTriageSwipe()
                } else if translation < -120 {
                    Task { await viewModel.convertToNextAction() }
                }
            }
    }
    
    private var verticalDismissGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                if value.translation.height > 120 && abs(value.translation.width) < 80 {
                    dismiss()
                }
            }
    }
    
    // MARK: - Actions
    
    private func handleTriageSwipe() {
        if let task = viewModel.currentTask,
           task.priority == nil || task.timeslot == nil {
            pendingMandatoryTaskID = task.id
            pendingMandatoryPriority = task.priority
            pendingMandatoryTimeslot = task.timeslot
            showingMandatorySheet = true
        } else {
            Task { await viewModel.assignCurrent() }
        }
    }
    
    private func handleError(_ error: String?) {
        guard let error = error else {
            pendingErrorMessage = nil
            return
        }
        if showingMandatorySheet || showingEditor || showingSyncError {
            pendingErrorMessage = error
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard !showingMandatorySheet, !showingEditor, !showingSyncError else {
                pendingErrorMessage = error
                return
            }
            syncErrorMessage = error
            showingSyncError = true
        }
    }
    
    private func handleSheetDismiss() {
        if let error = pendingErrorMessage {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                syncErrorMessage = error
                showingSyncError = true
                pendingErrorMessage = nil
            }
        }
    }
    
    private func resetMandatoryState() {
        pendingMandatoryTaskID = nil
        pendingMandatoryPriority = nil
        pendingMandatoryTimeslot = nil
    }
}

// MARK: - Inbox Card View

struct InboxCardView: View {
    let task: TaskDisplayModel
    let tint: Color
    let onSelectPriority: (TaskPriority?) -> Void
    let onSelectTimeslot: (TaskTimeslot?) -> Void
    let onSelectTimestamp: (Date?) -> Void
    let onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                    
                    if let type = task.type {
                        Text(type.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color(.systemFill))
                            )
                    }
                }
                
                Spacer()
                
                Button(action: onEdit) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Property editors
            VStack(spacing: 14) {
                propertyRow(
                    title: "Priority",
                    icon: "star.fill",
                    value: task.priority?.rawValue ?? "未設定",
                    color: TaskPalette.priorityColor(task.priority)
                ) {
                    Button("未設定") { onSelectPriority(nil) }
                    ForEach(TaskPriority.allCases, id: \.self) { priority in
                        Button(priority.rawValue) { onSelectPriority(priority) }
                    }
                }
                
                propertyRow(
                    title: "Timeslot",
                    icon: "clock.fill",
                    value: task.timeslot?.rawValue ?? "未設定",
                    color: TaskPalette.accentColor(for: task.timeslot)
                ) {
                    Button("未設定") { onSelectTimeslot(nil) }
                    ForEach(TaskTimeslot.allCases, id: \.self) { slot in
                        Button(slot.rawValue) { onSelectTimeslot(slot) }
                    }
                }
                
                propertyRow(
                    title: "日付",
                    icon: "calendar",
                    value: task.timestamp?.formatted(date: .abbreviated, time: .omitted) ?? "未設定",
                    color: .orange
                ) {
                    Button("未設定") { onSelectTimestamp(nil) }
                    Button("今日") { onSelectTimestamp(todayInTokyo()) }
                    Button("明日") { onSelectTimestamp(todayInTokyo().addingTimeInterval(86_400)) }
                }
            }
            
            // Memo
            if let memo = task.memo, !memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Memo")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    
                    Text(memo)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .lineLimit(4)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemFill).opacity(0.5))
                )
            }
            
            // Bookmark
            if let url = task.url, let label = task.bookmarkLabel {
                Link(destination: url) {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .font(.system(size: 14, weight: .semibold))
                        Text(label)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [tint, tint.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
    }
    
    private func propertyRow(
        title: String,
        icon: String,
        value: String,
        color: Color,
        @ViewBuilder menu: () -> some View
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Menu {
                menu()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                    Text(value)
                        .font(.system(size: 14, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(color)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(color.opacity(0.12))
                )
            }
        }
    }
    
    private func todayInTokyo() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .tokyo
        return calendar.startOfDay(for: Date())
    }
}
