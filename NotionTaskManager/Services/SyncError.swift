import Foundation

/// Detailed error types for Notion sync operations
enum SyncError: LocalizedError, Equatable {
    /// No network connection available
    case networkUnavailable

    /// Notion API authentication failed (invalid or expired token)
    case authenticationFailed

    /// Rate limited by Notion API
    case rateLimited(retryAfter: TimeInterval)

    /// Notion server error
    case serverError(statusCode: Int)

    /// Request timed out
    case timeout

    /// Database not found or access denied
    case databaseNotFound

    /// Page not found or access denied
    case pageNotFound(pageID: String)

    /// Invalid request format
    case invalidRequest(message: String)

    /// Local data conflict
    case conflict(taskID: String)

    /// Unknown error
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "インターネット接続がありません"
        case .authenticationFailed:
            return "Notion認証に失敗しました"
        case .rateLimited(let seconds):
            return "\(Int(seconds))秒後に再試行します"
        case .serverError(let code):
            return "サーバーエラーが発生しました (コード: \(code))"
        case .timeout:
            return "接続がタイムアウトしました"
        case .databaseNotFound:
            return "データベースが見つかりません"
        case .pageNotFound(let pageID):
            return "タスクが見つかりません (\(pageID.prefix(8))...)"
        case .invalidRequest(let message):
            return "リクエストエラー: \(message)"
        case .conflict(let taskID):
            return "データの競合が発生しました (\(taskID.prefix(8))...)"
        case .unknown(let message):
            return "エラー: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "ネットワーク接続を確認してください"
        case .authenticationFailed:
            return "設定からNotionトークンを再設定してください"
        case .rateLimited:
            return "しばらく待ってから再試行してください"
        case .serverError:
            return "しばらく待ってから再試行してください"
        case .timeout:
            return "ネットワーク環境を確認して再試行してください"
        case .databaseNotFound:
            return "設定からデータベースIDを確認してください"
        case .pageNotFound:
            return "タスクが削除された可能性があります"
        case .invalidRequest:
            return "アプリを再起動してください"
        case .conflict:
            return "最新の状態を取得中..."
        case .unknown:
            return "再試行してください"
        }
    }

    /// Recommended recovery action for UI
    var recoveryAction: RecoveryAction {
        switch self {
        case .networkUnavailable:
            return .waitForNetwork
        case .authenticationFailed:
            return .openSettings
        case .rateLimited:
            return .autoRetry
        case .serverError:
            return .autoRetry
        case .timeout:
            return .retry
        case .databaseNotFound:
            return .openSettings
        case .pageNotFound:
            return .dismiss
        case .invalidRequest:
            return .dismiss
        case .conflict:
            return .autoRetry
        case .unknown:
            return .retry
        }
    }

    /// Whether this error should trigger automatic retry
    var shouldAutoRetry: Bool {
        switch self {
        case .rateLimited, .serverError, .timeout, .conflict:
            return true
        case .networkUnavailable:
            return true  // Will retry when network is restored
        default:
            return false
        }
    }

    /// Retry delay for this error type
    var retryDelay: TimeInterval {
        switch self {
        case .rateLimited(let seconds):
            return seconds
        case .serverError:
            return 5.0
        case .timeout:
            return 3.0
        case .conflict:
            return 1.0
        default:
            return 2.0
        }
    }

    /// Icon for UI display
    var icon: String {
        switch self {
        case .networkUnavailable:
            return "wifi.slash"
        case .authenticationFailed:
            return "key.slash"
        case .rateLimited:
            return "hourglass"
        case .serverError:
            return "exclamationmark.icloud"
        case .timeout:
            return "clock.badge.exclamationmark"
        case .databaseNotFound, .pageNotFound:
            return "magnifyingglass"
        case .invalidRequest:
            return "xmark.circle"
        case .conflict:
            return "arrow.triangle.2.circlepath"
        case .unknown:
            return "exclamationmark.triangle"
        }
    }

    static func == (lhs: SyncError, rhs: SyncError) -> Bool {
        switch (lhs, rhs) {
        case (.networkUnavailable, .networkUnavailable):
            return true
        case (.authenticationFailed, .authenticationFailed):
            return true
        case (.rateLimited(let a), .rateLimited(let b)):
            return a == b
        case (.serverError(let a), .serverError(let b)):
            return a == b
        case (.timeout, .timeout):
            return true
        case (.databaseNotFound, .databaseNotFound):
            return true
        case (.pageNotFound(let a), .pageNotFound(let b)):
            return a == b
        case (.invalidRequest(let a), .invalidRequest(let b)):
            return a == b
        case (.conflict(let a), .conflict(let b)):
            return a == b
        case (.unknown(let a), .unknown(let b)):
            return a == b
        default:
            return false
        }
    }
}

/// Recovery actions for sync errors
enum RecoveryAction {
    /// Wait for network to be restored (automatic)
    case waitForNetwork

    /// Open settings to fix configuration
    case openSettings

    /// Automatic retry with backoff
    case autoRetry

    /// Manual retry button
    case retry

    /// Dismiss the error (no action needed)
    case dismiss

    var buttonTitle: String? {
        switch self {
        case .waitForNetwork:
            return nil  // No button, automatic
        case .openSettings:
            return "設定を開く"
        case .autoRetry:
            return nil  // No button, automatic
        case .retry:
            return "再試行"
        case .dismiss:
            return "閉じる"
        }
    }
}

/// Result of a sync operation
enum SyncResult: Equatable {
    /// Operation completed successfully
    case success

    /// Operation is queued and pending
    case pending

    /// Operation failed with error
    case failure(SyncError)

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var isPending: Bool {
        if case .pending = self { return true }
        return false
    }

    var error: SyncError? {
        if case .failure(let error) = self { return error }
        return nil
    }
}

/// Status of an individual sync operation
enum OperationStatus: Equatable {
    case pending
    case executing
    case retrying(attempt: Int, maxAttempts: Int)
    case completed
    case failed(SyncError)

    var isInProgress: Bool {
        switch self {
        case .pending, .executing, .retrying:
            return true
        default:
            return false
        }
    }

    var displayMessage: String {
        switch self {
        case .pending:
            return "待機中..."
        case .executing:
            return "同期中..."
        case .retrying(let attempt, let max):
            return "再試行中 (\(attempt)/\(max))..."
        case .completed:
            return "完了"
        case .failed(let error):
            return error.localizedDescription
        }
    }

    var icon: String {
        switch self {
        case .pending:
            return "clock"
        case .executing:
            return "arrow.triangle.2.circlepath"
        case .retrying:
            return "arrow.clockwise"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
}
