import Foundation

// MARK: - User
struct User: Codable, Identifiable {
    let id: String
    let username: String
}

// MARK: - Auth Response
struct AuthResponse: Codable {
    let message: String
    let token: String
    let user: User
}

// MARK: - Video
struct Video: Codable, Identifiable {
    let id: String
    let senderId: String
    let senderUsername: String?
    let status: VideoStatus
    let durationSeconds: Int?
    let fileSizeBytes: Int?
    let tiktokAuthor: String?
    let tiktokDescription: String?
    let message: String?
    let createdAt: Date
    let expiresAt: Date
    let streamUrl: String
    let thumbnailUrl: String
    
    var absoluteStreamURL: URL? {
        URL(string: "\(AppConfig.apiBaseURL)\(streamUrl)")
    }
    
    var absoluteThumbnailURL: URL? {
        URL(string: "\(AppConfig.apiBaseURL)\(thumbnailUrl)")
    }
}

enum VideoStatus: String, Codable {
    case processing
    case ready
    case failed
}

// MARK: - Video List Response
struct VideoListResponse: Codable {
    let videos: [Video]
}

// MARK: - Video Submit Response
struct VideoSubmitResponse: Codable {
    let message: String
    let video: VideoBasic
}

struct VideoBasic: Codable {
    let id: String
    let status: VideoStatus
}

// MARK: - Check Response
struct CheckResponse: Codable {
    let count: Int
    let hasNew: Bool
}

// MARK: - Error Response
struct APIErrorResponse: Codable {
    let error: String
    let details: ErrorDetails?
}

struct ErrorDetails: Codable {
    let fieldErrors: [String: [String]]?
}

// MARK: - Custom Date Decoding
extension Video {
    enum CodingKeys: String, CodingKey {
        case id, senderId, senderUsername, status
        case durationSeconds, fileSizeBytes
        case tiktokAuthor, tiktokDescription, message
        case createdAt, expiresAt
        case streamUrl, thumbnailUrl
    }
}
