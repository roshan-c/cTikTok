import Foundation

// MARK: - User
struct User: Codable, Identifiable {
    let id: String
    let username: String
    let friendCode: String?
    let pendingRequestCount: Int?
}

// MARK: - Auth Response
struct AuthResponse: Codable {
    let message: String
    let token: String
    let user: User
}

// MARK: - Friend
struct Friend: Codable, Identifiable {
    let id: String
    let username: String
    let createdAt: Date
}

// MARK: - Friend User (used in requests)
struct FriendUser: Codable, Identifiable {
    let id: String
    let username: String
}

// MARK: - Friend Request
struct FriendRequest: Codable, Identifiable {
    let id: String
    let fromUser: FriendUser?
    let toUser: FriendUser?
    let status: String
    let createdAt: Date
}

// MARK: - Friends Response
struct FriendsListResponse: Codable {
    let friends: [Friend]
}

// MARK: - Friend Requests Response
struct FriendRequestsResponse: Codable {
    let requests: [FriendRequest]
}

// MARK: - Friend Code Response
struct FriendCodeResponse: Codable {
    let code: String
}

// MARK: - Send Friend Request Response
struct SendFriendRequestResponse: Codable {
    let message: String
    let toUser: FriendUser?
    let friend: FriendUser?
}

// MARK: - Accept Friend Request Response
struct AcceptFriendRequestResponse: Codable {
    let message: String
    let friend: FriendUser
}

// MARK: - Generic Message Response
struct MessageResponse: Codable {
    let message: String
}

// MARK: - Media Type
enum MediaType: String, Codable {
    case video
    case slideshow
}

// MARK: - Video Status
enum VideoStatus: String, Codable {
    case processing
    case ready
    case failed
}

// MARK: - Video (also represents slideshows)
struct Video: Codable, Identifiable {
    let id: String
    let senderId: String
    let senderUsername: String?
    let mediaType: MediaType
    let status: VideoStatus
    let durationSeconds: Int?
    let fileSizeBytes: Int?
    let tiktokAuthor: String?
    let tiktokDescription: String?
    let message: String?
    let createdAt: Date
    let expiresAt: Date
    let thumbnailUrl: String
    let isFavorited: Bool?
    
    // Video-specific
    let streamUrl: String?
    
    // Slideshow-specific
    let imageCount: Int?
    let imageUrls: [String]?
    let audioUrl: String?
    
    var isSlideshow: Bool {
        mediaType == .slideshow
    }
    
    var isFavoritedValue: Bool {
        isFavorited ?? false
    }
    
    var absoluteStreamURL: URL? {
        guard let streamUrl = streamUrl else { return nil }
        return URL(string: "\(AppConfig.apiBaseURL)\(streamUrl)")
    }
    
    var absoluteThumbnailURL: URL? {
        URL(string: "\(AppConfig.apiBaseURL)\(thumbnailUrl)")
    }
    
    var absoluteImageURLs: [URL] {
        guard let imageUrls = imageUrls else { return [] }
        return imageUrls.compactMap { URL(string: "\(AppConfig.apiBaseURL)\($0)") }
    }
    
    var absoluteAudioURL: URL? {
        guard let audioUrl = audioUrl else { return nil }
        return URL(string: "\(AppConfig.apiBaseURL)\(audioUrl)")
    }
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
        case id, senderId, senderUsername, mediaType, status
        case durationSeconds, fileSizeBytes
        case tiktokAuthor, tiktokDescription, message
        case createdAt, expiresAt
        case thumbnailUrl, streamUrl
        case imageCount, imageUrls, audioUrl
        case isFavorited
    }
}

// MARK: - Favorite Response
struct FavoriteResponse: Codable {
    let success: Bool
    let isFavorited: Bool
    let scheduledDeletionAt: Date?
}
