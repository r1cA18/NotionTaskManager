import SwiftUI

struct OverdueCarouselView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: OverdueCarouselViewModel
    @State private var showingEditor = false
    @State private var showingMandatorySheet = false
    @State private var pendingMandatoryTaskID: String?
    @State private var pendingMandatoryPriority: TaskPriority?
    @State private var pendingMandatoryTimeslot: TaskTimeslot?
    @State private var showingSyncError = false
    @State private var syncErrorMessage = ""
    @State private var pendingErrorMessage: String?
    @GestureState private var horizontalOffset: CGFloat = 0
    
    init(viewModel: OverdueCarouselViewModel) {
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
            .navigationTitle("期限切れ")
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
                    Color.red.opacity(0.05),
                    Color.orange.opacity(0.03),
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
            Image(systemName: "checkmark.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.green)
            
            VStack(spacing: 8) {
                Text("すべて処理済み！")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text("期限切れタスクはすべて振り直されました")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }
    
    // MARK: - Card View
    
    @ViewBuilder
    private func cardView(for task: TaskDisplayModel) -> some View {
        VStack(spacing: 0) {
            // Warning banner
            warningBanner(for: task)
            
            // Swipe hints
            swipeHints
            
            // Main card
            InboxCardView(
                task: task,
                tint: Color.red,
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
    
    private func warningBanner(for task: TaskDisplayModel) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
            
            if let timestamp = task.timestamp {
                Text("\(daysOverdue(from: timestamp))日経過")
                    .font(.system(size: 14, weight: .semibold))
            } else {
                Text("日付未設定")
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.red, Color.red.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
    
    private var swipeHints: some View {
        HStack {
            if horizontalOffset > 20 {
                swipeLabel(icon: "tray.and.arrow.down.fill", text: "今日に振り直し", color: .blue)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            Spacer()
            if horizontalOffset < -20 {
                swipeLabel(icon: "trash.fill", text: "削除", color: .red)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 8)
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
                            .fill(index == 0 ? Color.red : Color(.systemFill))
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
                    Task { await viewModel.trashCurrent() }
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
    
    private func daysOverdue(from timestamp: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .tokyo
        let today = calendar.startOfDay(for: Date())
        let taskDate = calendar.startOfDay(for: timestamp)
        let components = calendar.dateComponents([.day], from: taskDate, to: today)
        return max(0, components.day ?? 0)
    }
}
