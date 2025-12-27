import Foundation

// MARK: - API Configuration
// cTikTok app configuration
enum AppConfig {
    static let apiBaseURL = "https://ctiktok.roshanc.com"
    static let appGroupIdentifier = "group.com.roshanc.ctiktok"
    static let keychainAccessGroup = "group.com.roshanc.ctiktok"
    static let backgroundTaskIdentifier = "com.roshanc.ctiktok.refresh"
}

// MARK: - Keychain Keys
enum KeychainKeys {
    static let authToken = "authToken"
    static let userId = "userId"
    static let username = "username"
}
