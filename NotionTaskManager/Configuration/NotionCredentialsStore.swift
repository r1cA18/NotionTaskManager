import Foundation
import Combine
import SwiftUI

@MainActor
final class NotionCredentialsStore: ObservableObject {
    @Published var token: String {
        didSet {
            persistToken()
        }
    }

    private let tokenStore: TokenStore

    init(tokenStore: TokenStore? = nil) {
        self.tokenStore = tokenStore ?? SecureTokenStore()
        self.token = (try? self.tokenStore.loadToken()) ?? ""
    }

    func clear() {
        token = ""
        try? tokenStore.clearToken()
    }

    private func persistToken() {
        guard !token.isEmpty else {
            try? tokenStore.clearToken()
            return
        }
        try? tokenStore.saveToken(token)
    }
}
