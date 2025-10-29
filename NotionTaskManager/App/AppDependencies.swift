import Foundation
import Combine
import SwiftUI

@MainActor
final class AppDependencies: ObservableObject {
    let settingsStore: AppSettingsStore
    let credentialsStore: NotionCredentialsStore
    let notionClient: NotionClientProtocol

    init(settingsStore: AppSettingsStore? = nil,
         credentialsStore: NotionCredentialsStore? = nil,
         notionClient: NotionClientProtocol? = nil) {
        self.settingsStore = settingsStore ?? AppSettingsStore()
        self.credentialsStore = credentialsStore ?? NotionCredentialsStore()
        if let notionClient {
            self.notionClient = notionClient
        } else {
            self.notionClient = NotionClient()
        }
    }

    func currentCredentials() -> NotionCredentials? {
        let token = credentialsStore.token
        let databaseID = settingsStore.databaseID
        let notionVersion = settingsStore.notionVersion
        let credentials = NotionCredentials(token: token, databaseID: databaseID, notionVersion: notionVersion)
        return credentials.isUsable ? credentials : nil
    }
}
