import Combine
import Foundation
import SwiftUI

@MainActor
final class AppDependencies: ObservableObject {
    let settingsStore: AppSettingsStore
    let credentialsStore: NotionCredentialsStore
    let notionClient: NotionClientProtocol

    /// Network connectivity monitor
    let networkMonitor: NetworkMonitor

    /// Toast notification manager
    let toastManager: ToastManager

    init(
        settingsStore: AppSettingsStore? = nil,
        credentialsStore: NotionCredentialsStore? = nil,
        notionClient: NotionClientProtocol? = nil
    ) {
        self.settingsStore = settingsStore ?? AppSettingsStore()
        self.credentialsStore = credentialsStore ?? NotionCredentialsStore()
        if let notionClient {
            self.notionClient = notionClient
        } else {
            self.notionClient = NotionClient()
        }

        self.networkMonitor = NetworkMonitor()
        self.toastManager = ToastManager()

        // Start network monitoring
        self.networkMonitor.start()
    }

    func currentCredentials() -> NotionCredentials? {
        let token = credentialsStore.token
        let databaseID = settingsStore.databaseID
        let notionVersion = settingsStore.notionVersion
        let credentials = NotionCredentials(
            token: token, databaseID: databaseID, notionVersion: notionVersion)
        return credentials.isUsable ? credentials : nil
    }

    /// Configure sync service with network monitor and toast callbacks
    func configureSyncService(_ syncService: TaskSyncService) {
        // Link network monitor to operation queue
        syncService.operationQueue.networkMonitor = networkMonitor

        // Set up network restored callback
        networkMonitor.onNetworkRestored = { [weak syncService] in
            await syncService?.operationQueue.resumePendingOperations()
        }
    }
}
