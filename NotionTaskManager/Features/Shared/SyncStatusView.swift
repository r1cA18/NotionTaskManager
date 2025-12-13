import Combine
import SwiftUI

// MARK: - Sync Status Bar (for Toolbar)

/// Compact sync status indicator for toolbar
struct SyncStatusIndicator: View {
    @ObservedObject var syncService: TaskSyncService
    @ObservedObject var networkMonitor: NetworkMonitor

    var body: some View {
        HStack(spacing: 4) {
            statusIcon
                .font(.system(size: 14))
                .foregroundStyle(statusColor)

            if showBadge {
                Text("\(badgeCount)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(badgeColor, in: Capsule())
            }
        }
        .animation(.easeInOut(duration: 0.2), value: syncService.isSyncing)
        .animation(.easeInOut(duration: 0.2), value: syncService.operationQueue.failedCount)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if !networkMonitor.isConnected {
            Image(systemName: "wifi.slash")
                .symbolEffect(.pulse)
        } else if syncService.isSyncing || syncService.operationQueue.pendingCount > 0 {
            Image(systemName: "arrow.triangle.2.circlepath")
                .symbolEffect(.rotate, options: .repeat(.continuous))
        } else if syncService.operationQueue.failedCount > 0 {
            Image(systemName: "exclamationmark.triangle.fill")
        } else {
            Image(systemName: "checkmark.icloud")
        }
    }

    private var statusColor: Color {
        if !networkMonitor.isConnected {
            return .orange
        } else if syncService.operationQueue.failedCount > 0 {
            return .red
        } else if syncService.isSyncing || syncService.operationQueue.pendingCount > 0 {
            return .blue
        } else {
            return .green
        }
    }

    private var showBadge: Bool {
        syncService.operationQueue.failedCount > 0 || syncService.operationQueue.pendingCount > 0
    }

    private var badgeCount: Int {
        syncService.operationQueue.failedCount + syncService.operationQueue.pendingCount
    }

    private var badgeColor: Color {
        syncService.operationQueue.failedCount > 0 ? .red : .blue
    }
}

// MARK: - Sync Status Banner (for Top of Screen)

/// Full-width sync status banner
struct SyncStatusBanner: View {
    @ObservedObject var syncService: TaskSyncService
    @ObservedObject var networkMonitor: NetworkMonitor
    @State private var isExpanded = false

    var body: some View {
        if shouldShow {
            VStack(spacing: 0) {
                mainBanner
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            isExpanded.toggle()
                        }
                    }

                if isExpanded {
                    expandedContent
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            .padding(.horizontal)
        }
    }

    private var shouldShow: Bool {
        !networkMonitor.isConnected
            || syncService.operationQueue.failedCount > 0
            || syncService.isSyncing
    }

    private var mainBanner: some View {
        HStack(spacing: 12) {
            statusIcon
                .font(.system(size: 18))
                .foregroundStyle(statusColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.subheadline.weight(.medium))

                if let subtitle = statusSubtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let action = primaryAction {
                Button(action.title) {
                    action.handler()
                }
                .font(.subheadline.weight(.medium))
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.horizontal)

            if syncService.operationQueue.failedCount > 0 {
                failedOperationsList
            }

            if syncService.operationQueue.pendingCount > 0 {
                pendingOperationsList
            }
        }
        .padding(.bottom, 12)
    }

    private var failedOperationsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("失敗した操作")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ForEach(Array(syncService.operationQueue.failedOperations.values), id: \.id) { operation in
                HStack {
                    Image(systemName: operation.operationType.icon)
                        .foregroundStyle(.red)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(operation.operationType.rawValue)
                            .font(.subheadline)

                        if let error = operation.lastError {
                            Text(error.localizedDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Button {
                        syncService.operationQueue.retryFailedOperation(for: operation.taskID)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal)
            }
        }
    }

    private var pendingOperationsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("待機中の操作")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ForEach(Array(syncService.operationQueue.pendingOperations.values), id: \.id) { operation in
                HStack {
                    Image(systemName: operation.operationType.icon)
                        .foregroundStyle(.blue)

                    Text(operation.operationType.rawValue)
                        .font(.subheadline)

                    Spacer()

                    Text(operation.status.displayMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        if !networkMonitor.isConnected {
            Image(systemName: "wifi.slash")
                .symbolEffect(.pulse)
        } else if syncService.operationQueue.failedCount > 0 {
            Image(systemName: "exclamationmark.triangle.fill")
        } else if syncService.isSyncing {
            Image(systemName: "arrow.triangle.2.circlepath")
                .symbolEffect(.rotate, options: .repeat(.continuous))
        } else {
            Image(systemName: "checkmark.circle.fill")
        }
    }

    private var statusColor: Color {
        if !networkMonitor.isConnected {
            return .orange
        } else if syncService.operationQueue.failedCount > 0 {
            return .red
        } else if syncService.isSyncing {
            return .blue
        } else {
            return .green
        }
    }

    private var statusTitle: String {
        if !networkMonitor.isConnected {
            return "オフライン"
        } else if syncService.operationQueue.failedCount > 0 {
            return "\(syncService.operationQueue.failedCount)件の同期に失敗"
        } else if syncService.isSyncing {
            return "同期中..."
        } else {
            return "同期済み"
        }
    }

    private var statusSubtitle: String? {
        if !networkMonitor.isConnected {
            return "接続が回復すると自動的に同期します"
        } else if syncService.operationQueue.failedCount > 0 {
            return "タップして詳細を確認"
        } else if case .fetchingBookmarks(let current, let total) = syncService.syncProgress {
            return "ブックマーク取得中 (\(current)/\(total))"
        } else {
            return nil
        }
    }

    private var primaryAction: (title: String, handler: () -> Void)? {
        if syncService.operationQueue.failedCount > 0 {
            return ("すべて再試行", { syncService.operationQueue.retryAllFailed() })
        }
        return nil
    }
}

// MARK: - Task Sync Status Dot

/// Small indicator dot for individual task sync status
struct TaskSyncStatusDot: View {
    let taskID: String
    @ObservedObject var operationQueue: SyncOperationQueue

    var body: some View {
        if let status = operationQueue.status(for: taskID) {
            Circle()
                .fill(statusColor(for: status))
                .frame(width: 8, height: 8)
                .overlay {
                    if case .executing = status {
                        Circle()
                            .stroke(statusColor(for: status).opacity(0.5), lineWidth: 2)
                            .scaleEffect(1.5)
                            .opacity(0.5)
                    }
                }
                .animation(.easeInOut, value: status)
        }
    }

    private func statusColor(for status: OperationStatus) -> Color {
        switch status {
        case .pending:
            return .gray
        case .executing:
            return .blue
        case .retrying:
            return .orange
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
}

// MARK: - Toast Notification

/// Toast notification for sync events
struct SyncToast: View {
    let message: String
    let type: ToastType
    let onDismiss: () -> Void

    enum ToastType {
        case success
        case error
        case info

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            case .info: return .blue
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .foregroundStyle(type.color)

            Text(message)
                .font(.subheadline)

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .padding(.horizontal)
    }
}

// MARK: - Toast Manager

/// Manages toast notifications
@MainActor
final class ToastManager: ObservableObject {
    @Published var currentToast: Toast?

    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let type: SyncToast.ToastType
        let duration: TimeInterval

        static func == (lhs: Toast, rhs: Toast) -> Bool {
            lhs.id == rhs.id
        }
    }

    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, type: SyncToast.ToastType = .info, duration: TimeInterval = 3.0) {
        dismissTask?.cancel()

        withAnimation(.spring(response: 0.3)) {
            currentToast = Toast(message: message, type: type, duration: duration)
        }

        dismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if !Task.isCancelled {
                await MainActor.run {
                    self.dismiss()
                }
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.3)) {
            currentToast = nil
        }
    }
}

// MARK: - Toast Container View Modifier

struct ToastContainerModifier: ViewModifier {
    @ObservedObject var toastManager: ToastManager

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = toastManager.currentToast {
                    SyncToast(
                        message: toast.message,
                        type: toast.type,
                        onDismiss: { toastManager.dismiss() }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
                }
            }
    }
}

extension View {
    func toastContainer(_ manager: ToastManager) -> some View {
        modifier(ToastContainerModifier(toastManager: manager))
    }
}
