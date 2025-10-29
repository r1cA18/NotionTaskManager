import Foundation

struct NotionCredentials {
  let token: String
  let databaseID: String
  let notionVersion: String

  var isUsable: Bool {
    !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !databaseID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}

enum NotionClientError: Error {
  case missingCredentials
  case invalidResponse
  case httpError(statusCode: Int, data: Data)
}

extension NotionClientError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .missingCredentials:
      return "Missing Notion API credentials."
    case .invalidResponse:
      return "Received an invalid response from Notion."
    case .httpError(let statusCode, let data):
      let body = String(data: data, encoding: .utf8)?.trimmingCharacters(
        in: .whitespacesAndNewlines)
      if let body, !body.isEmpty {
        return "Notion API returned status \(statusCode): \(body)"
      } else {
        return "Notion API returned status \(statusCode)."
      }
    }
  }
}

protocol NotionClientProtocol {
  func queryDatabase(credentials: NotionCredentials, request: NotionDatabaseQueryRequest)
    async throws -> NotionDatabaseQueryResponse
  func updatePage(credentials: NotionCredentials, pageID: String, request: NotionPageUpdateRequest)
    async throws -> NotionPageObject
  func fetchBlockChildren(
    credentials: NotionCredentials,
    blockID: String,
    pageSize: Int?,
    startCursor: String?
  ) async throws -> NotionBlockChildrenResponse
  func firstBookmarkURL(credentials: NotionCredentials, pageID: String) async throws -> URL?
}

final class NotionClient: NotionClientProtocol {
  private let session: URLSession
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  init(session: URLSession = .shared) {
    self.session = session
    self.encoder = JSONEncoder()
    self.encoder.keyEncodingStrategy = .convertToSnakeCase
    self.decoder = JSONDecoder()
    self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    self.decoder.dateDecodingStrategy = .iso8601
  }

  func queryDatabase(credentials: NotionCredentials, request: NotionDatabaseQueryRequest)
    async throws -> NotionDatabaseQueryResponse
  {
    guard credentials.isUsable else {
      throw NotionClientError.missingCredentials
    }

    let url = URL(string: "https://api.notion.com/v1/databases/\(credentials.databaseID)/query")!
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.httpBody = try encoder.encode(request)
    applyStandardHeaders(&urlRequest, credentials: credentials)

    let (data, response) = try await session.data(for: urlRequest)
    return try handleResponse(data: data, response: response)
  }

  func updatePage(credentials: NotionCredentials, pageID: String, request: NotionPageUpdateRequest)
    async throws -> NotionPageObject
  {
    guard credentials.isUsable else {
      throw NotionClientError.missingCredentials
    }

    let url = URL(string: "https://api.notion.com/v1/pages/\(pageID)")!
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "PATCH"
    urlRequest.httpBody = try encoder.encode(request)
    applyStandardHeaders(&urlRequest, credentials: credentials)

    let (data, response) = try await session.data(for: urlRequest)
    let decoded: NotionPageObject = try decodeResponse(data: data, response: response)
    return decoded
  }

  func fetchBlockChildren(
    credentials: NotionCredentials,
    blockID: String,
    pageSize: Int?,
    startCursor: String?
  ) async throws -> NotionBlockChildrenResponse {
    guard credentials.isUsable else {
      throw NotionClientError.missingCredentials
    }

    let normalizedID = NotionClient.normalizeIdentifier(blockID)
    var components = URLComponents(
      string: "https://api.notion.com/v1/blocks/\(normalizedID)/children")!
    var queryItems: [URLQueryItem] = []
    if let pageSize {
      queryItems.append(URLQueryItem(name: "page_size", value: "\(pageSize)"))
    }
    if let startCursor {
      queryItems.append(URLQueryItem(name: "start_cursor", value: startCursor))
    }
    if !queryItems.isEmpty {
      components.queryItems = queryItems
    }
    var request = URLRequest(url: components.url!)
    request.httpMethod = "GET"
    applyStandardHeaders(&request, credentials: credentials)

    let (data, response) = try await session.data(for: request)
    return try decodeResponse(data: data, response: response)
  }

  func firstBookmarkURL(credentials: NotionCredentials, pageID: String) async throws -> URL? {
    var cursor: String?
    var pageCount = 0
    repeat {
      pageCount += 1
      let response = try await fetchBlockChildren(
        credentials: credentials,
        blockID: pageID,
        pageSize: 50,
        startCursor: cursor
      )

      #if DEBUG
        print("[NotionClient] 📄 Page \(pageCount): Found \(response.results.count) blocks")
        for (index, block) in response.results.prefix(5).enumerated() {
          print(
            "[NotionClient]   Block \(index): type=\(block.type), hasChildren=\(block.hasChildren)")
          if block.type == "bookmark", let url = block.bookmark?.url {
            print("[NotionClient]   ✅ Bookmark found: \(url.absoluteString)")
          }
        }
      #endif

      if let bookmarkURL = response.results
        .first(where: { $0.type == "bookmark" })?.bookmark?.url
      {
        return bookmarkURL
      }

      cursor = response.hasMore ? response.nextCursor : nil
    } while cursor != nil

    return nil
  }

  private static func normalizeIdentifier(_ id: String) -> String {
    id.replacingOccurrences(of: "-", with: "")
  }

  private func applyStandardHeaders(_ request: inout URLRequest, credentials: NotionCredentials) {
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(credentials.token)", forHTTPHeaderField: "Authorization")
    request.setValue(credentials.notionVersion, forHTTPHeaderField: "Notion-Version")
  }

  private func handleResponse(data: Data, response: URLResponse) throws
    -> NotionDatabaseQueryResponse
  {
    let decoded: NotionDatabaseQueryResponse = try decodeResponse(data: data, response: response)
    return decoded
  }

  private func decodeResponse<T: Decodable>(data: Data, response: URLResponse) throws -> T {
    guard let httpResponse = response as? HTTPURLResponse else {
      throw NotionClientError.invalidResponse
    }

    #if DEBUG
      print("[NotionClient] HTTP \(httpResponse.statusCode) - Response size: \(data.count) bytes")
    #endif

    guard (200..<300).contains(httpResponse.statusCode) else {
      throw NotionClientError.httpError(statusCode: httpResponse.statusCode, data: data)
    }

    return try decoder.decode(T.self, from: data)
  }
}

struct NotionDatabaseQueryRequest: Encodable {
  var filter: JSONValue?
  var sorts: [JSONValue]?
  var pageSize: Int?
  var startCursor: String?

  init(
    filter: JSONValue? = nil, sorts: [JSONValue]? = nil, pageSize: Int? = nil,
    startCursor: String? = nil
  ) {
    self.filter = filter
    self.sorts = sorts
    self.pageSize = pageSize
    self.startCursor = startCursor
  }
}

struct NotionDatabaseQueryResponse: Decodable {
  let results: [NotionPageObject]
  let nextCursor: String?
  let hasMore: Bool
}

struct NotionBlockChildrenResponse: Decodable {
  let results: [NotionBlockObject]
  let nextCursor: String?
  let hasMore: Bool
}

struct NotionPageUpdateRequest: Encodable {
  let properties: [String: JSONValue]
  let archived: Bool?

  init(properties: [String: JSONValue], archived: Bool? = nil) {
    self.properties = properties
    self.archived = archived
  }
}

struct NotionPageObject: Decodable {
  let id: String
  let createdTime: Date
  let lastEditedTime: Date
  let url: URL?
  let properties: [String: NotionPropertyValue]
}

struct NotionBlockObject: Decodable {
  let id: String
  let type: String
  let hasChildren: Bool
  let bookmark: NotionBookmarkValue?

  private enum CodingKeys: String, CodingKey {
    case id
    case type
    case hasChildren = "has_children"
    case bookmark
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    type = try container.decode(String.self, forKey: .type)
    hasChildren = try container.decodeIfPresent(Bool.self, forKey: .hasChildren) ?? false
    bookmark = try container.decodeIfPresent(NotionBookmarkValue.self, forKey: .bookmark)
  }
}

struct NotionBookmarkValue: Decodable {
  let url: URL
  let caption: [JSONValue]?
}

struct NotionPropertyValue: Decodable {
  let id: String?
  let type: String
  let rawValue: JSONValue

  private struct CodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
      self.stringValue = stringValue
      self.intValue = nil
    }

    init?(intValue: Int) {
      self.stringValue = "\(intValue)"
      self.intValue = intValue
    }

    static let id = CodingKeys(stringValue: "id")!
    static let type = CodingKeys(stringValue: "type")!
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeIfPresent(String.self, forKey: .id)
    type = try container.decode(String.self, forKey: .type)
    let typeKey = CodingKeys(stringValue: type)
    if let typeKey, container.contains(typeKey) {
      rawValue = try container.decode(JSONValue.self, forKey: typeKey)
    } else {
      rawValue = .null
    }
  }
}
