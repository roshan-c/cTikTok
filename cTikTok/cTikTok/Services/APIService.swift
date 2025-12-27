import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(String)
    case unauthorized
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .unauthorized:
            return "Please log in again"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

@MainActor
final class APIService: ObservableObject {
    static let shared = APIService()
    
    private let baseURL = AppConfig.apiBaseURL
    private let session: URLSession
    private let decoder: JSONDecoder
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            // Try ISO8601 string first
            if let dateString = try? container.decode(String.self) {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: dateString) {
                    return date
                }
                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            // Try timestamp (seconds since epoch)
            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp)
            }
            // Try integer timestamp
            if let timestamp = try? container.decode(Int.self) {
                return Date(timeIntervalSince1970: Double(timestamp))
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode date")
        }
    }
    
    private var authToken: String? {
        KeychainHelper.shared.loadString(forKey: KeychainKeys.authToken)
    }
    
    // MARK: - Generic Request
    private func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if requiresAuth {
            guard let token = authToken else {
                throw APIError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        if httpResponse.statusCode >= 400 {
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error)
            }
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    // MARK: - Auth
    func register(username: String, password: String) async throws -> AuthResponse {
        try await request(
            endpoint: "/api/auth/register",
            method: "POST",
            body: ["username": username, "password": password],
            requiresAuth: false
        )
    }
    
    func login(username: String, password: String) async throws -> AuthResponse {
        try await request(
            endpoint: "/api/auth/login",
            method: "POST",
            body: ["username": username, "password": password],
            requiresAuth: false
        )
    }
    
    // MARK: - Videos
    func getVideos(hours: Int = 168) async throws -> [Video] {
        let response: VideoListResponse = try await request(
            endpoint: "/api/videos?hours=\(hours)"
        )
        return response.videos
    }
    
    func submitVideo(url: String, message: String? = nil) async throws -> VideoSubmitResponse {
        var body: [String: Any] = ["url": url]
        if let message = message, !message.isEmpty {
            body["message"] = message
        }
        return try await request(
            endpoint: "/api/videos",
            method: "POST",
            body: body
        )
    }
    
    func checkForNewVideos(since: Date) async throws -> CheckResponse {
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: since)
        return try await request(
            endpoint: "/api/videos/check?since=\(timestamp)"
        )
    }
    
    func deleteVideo(id: String) async throws {
        let _: [String: String] = try await request(
            endpoint: "/api/videos/\(id)",
            method: "DELETE"
        )
    }
    
    // MARK: - Favorites
    func getFavorites() async throws -> [Video] {
        let response: VideoListResponse = try await request(
            endpoint: "/api/videos/favorites"
        )
        return response.videos
    }
    
    func favoriteVideo(id: String) async throws -> FavoriteResponse {
        try await request(
            endpoint: "/api/videos/\(id)/favorite",
            method: "POST"
        )
    }
    
    func unfavoriteVideo(id: String) async throws -> FavoriteResponse {
        try await request(
            endpoint: "/api/videos/\(id)/favorite",
            method: "DELETE"
        )
    }
    
    // MARK: - Friends
    func getFriends() async throws -> [Friend] {
        let response: FriendsListResponse = try await request(
            endpoint: "/api/friends"
        )
        return response.friends
    }
    
    func getIncomingRequests() async throws -> [FriendRequest] {
        let response: FriendRequestsResponse = try await request(
            endpoint: "/api/friends/requests"
        )
        return response.requests
    }
    
    func getOutgoingRequests() async throws -> [FriendRequest] {
        let response: FriendRequestsResponse = try await request(
            endpoint: "/api/friends/requests/outgoing"
        )
        return response.requests
    }
    
    func sendFriendRequest(code: String) async throws -> SendFriendRequestResponse {
        try await request(
            endpoint: "/api/friends/request",
            method: "POST",
            body: ["code": code]
        )
    }
    
    func acceptFriendRequest(id: String) async throws -> AcceptFriendRequestResponse {
        try await request(
            endpoint: "/api/friends/requests/\(id)/accept",
            method: "POST"
        )
    }
    
    func rejectFriendRequest(id: String) async throws -> MessageResponse {
        try await request(
            endpoint: "/api/friends/requests/\(id)/reject",
            method: "POST"
        )
    }
    
    func removeFriend(id: String) async throws -> MessageResponse {
        try await request(
            endpoint: "/api/friends/\(id)",
            method: "DELETE"
        )
    }
    
    func getFriendCode() async throws -> String {
        let response: FriendCodeResponse = try await request(
            endpoint: "/api/friends/code"
        )
        return response.code
    }
    
    func regenerateFriendCode() async throws -> String {
        let response: FriendCodeResponse = try await request(
            endpoint: "/api/friends/code/regenerate",
            method: "POST"
        )
        return response.code
    }
    
    func getCurrentUser() async throws -> User {
        try await request(endpoint: "/api/auth/me")
    }
}
