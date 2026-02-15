import Combine
import Foundation
import Network

/// Monitors network connectivity status and notifies observers of changes
@MainActor
final class NetworkMonitor: ObservableObject {
    /// Current network connection status
    @Published private(set) var isConnected = true

    /// Type of current network connection
    @Published private(set) var connectionType: ConnectionType = .unknown

    /// Detailed status message for UI display
    @Published private(set) var statusMessage: String = ""

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var isStarted = false

    /// Callback to resume pending sync operations when network becomes available
    var onNetworkRestored: (() async -> Void)?

    enum ConnectionType: String {
        case wifi = "Wi-Fi"
        case cellular = "モバイルデータ"
        case wired = "有線"
        case unknown = "不明"

        var icon: String {
            switch self {
            case .wifi: return "wifi"
            case .cellular: return "antenna.radiowaves.left.and.right"
            case .wired: return "cable.connector"
            case .unknown: return "network"
            }
        }
    }

    init() {}

    deinit {
        // monitor.cancel() is thread-safe and can be called from deinit
        monitor.cancel()
    }

    /// Start monitoring network status
    func start() {
        guard !isStarted else { return }
        isStarted = true

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }

                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied
                self.connectionType = self.determineConnectionType(path)
                self.updateStatusMessage(path)

                // Log status change
                #if DEBUG
                print("[NetworkMonitor] Status: \(self.isConnected ? "Connected" : "Disconnected") via \(self.connectionType.rawValue)")
                #endif

                // Trigger sync resume when network is restored
                if !wasConnected && self.isConnected {
                    await self.handleNetworkRestored()
                }
            }
        }

        monitor.start(queue: monitorQueue)
    }

    /// Stop monitoring network status
    func stop() {
        guard isStarted else { return }
        monitor.cancel()
        isStarted = false
    }

    private func determineConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wired
        } else {
            return .unknown
        }
    }

    private func updateStatusMessage(_ path: NWPath) {
        if path.status == .satisfied {
            if path.isExpensive {
                statusMessage = "\(connectionType.rawValue)（従量制）"
            } else if path.isConstrained {
                statusMessage = "\(connectionType.rawValue)（低データモード）"
            } else {
                statusMessage = connectionType.rawValue
            }
        } else if path.status == .requiresConnection {
            statusMessage = "接続を待機中..."
        } else {
            statusMessage = "オフライン"
        }
    }

    private func handleNetworkRestored() async {
        #if DEBUG
        print("[NetworkMonitor] Network restored, triggering pending sync...")
        #endif

        await onNetworkRestored?()
    }

    /// Check if current connection is metered (cellular or constrained)
    var isMeteredConnection: Bool {
        connectionType == .cellular
    }
}
