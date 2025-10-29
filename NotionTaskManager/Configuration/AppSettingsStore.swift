import Foundation
import Combine
import SwiftUI

@MainActor
final class AppSettingsStore: ObservableObject {
    @Published var databaseID: String {
        didSet { persistDatabaseID() }
    }

    @Published var notionVersion: String {
        didSet { persistNotionVersion() }
    }

    private let userDefaults: UserDefaults
    private enum Keys {
        static let databaseID = "notion.databaseID"
        static let notionVersion = "notion.api.version"
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.databaseID = userDefaults.string(forKey: Keys.databaseID) ?? ""
        self.notionVersion = userDefaults.string(forKey: Keys.notionVersion) ?? "2022-06-28"
    }

    private func persistDatabaseID() {
        userDefaults.set(databaseID, forKey: Keys.databaseID)
    }

    private func persistNotionVersion() {
        userDefaults.set(notionVersion, forKey: Keys.notionVersion)
    }
}
