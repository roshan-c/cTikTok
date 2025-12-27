import Foundation
import AVFoundation

actor VideoCache {
    static let shared = VideoCache()
    
    private let cacheDirectory: URL
    private let audioCacheDirectory: URL
    private let maxCacheSize: Int64 = 500 * 1024 * 1024 // 500 MB
    private var cachedVideos: [String: URL] = [:]
    private var cachedAudio: [String: URL] = [:]
    
    private init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        self.cacheDirectory = paths[0].appendingPathComponent("VideoCache", isDirectory: true)
        self.audioCacheDirectory = paths[0].appendingPathComponent("AudioCache", isDirectory: true)
        
        // Create cache directories if needed
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: audioCacheDirectory, withIntermediateDirectories: true)
        
        // Load existing cached files
        Task {
            await loadExistingCache()
        }
    }
    
    private func loadExistingCache() {
        // Load video cache
        if let files = try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "mp4" {
                let videoId = file.deletingPathExtension().lastPathComponent
                cachedVideos[videoId] = file
            }
        }
        
        // Load audio cache
        if let files = try? FileManager.default.contentsOfDirectory(at: audioCacheDirectory, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "mp3" {
                let videoId = file.deletingPathExtension().lastPathComponent
                cachedAudio[videoId] = file
            }
        }
    }
    
    func getCachedURL(for videoId: String) -> URL? {
        return cachedVideos[videoId]
    }
    
    func getCachedAudioURL(for videoId: String) -> URL? {
        return cachedAudio[videoId]
    }
    
    func cacheVideo(from remoteURL: URL, videoId: String) async throws -> URL {
        // Check if already cached
        if let cached = cachedVideos[videoId], FileManager.default.fileExists(atPath: cached.path) {
            return cached
        }
        
        let localURL = cacheDirectory.appendingPathComponent("\(videoId).mp4")
        
        // Download video
        let (tempURL, _) = try await URLSession.shared.download(from: remoteURL)
        
        // Move to cache directory
        try? FileManager.default.removeItem(at: localURL)
        try FileManager.default.moveItem(at: tempURL, to: localURL)
        
        cachedVideos[videoId] = localURL
        
        // Clean up old cache if needed
        await cleanupCacheIfNeeded()
        
        return localURL
    }
    
    func cacheAudio(from remoteURL: URL, videoId: String) async throws -> URL {
        // Check if already cached
        if let cached = cachedAudio[videoId], FileManager.default.fileExists(atPath: cached.path) {
            return cached
        }
        
        let localURL = audioCacheDirectory.appendingPathComponent("\(videoId).mp3")
        
        // Download audio
        let (tempURL, _) = try await URLSession.shared.download(from: remoteURL)
        
        // Move to cache directory
        try? FileManager.default.removeItem(at: localURL)
        try FileManager.default.moveItem(at: tempURL, to: localURL)
        
        cachedAudio[videoId] = localURL
        
        return localURL
    }
    
    private func cleanupCacheIfNeeded() {
        let fileManager = FileManager.default
        
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) else {
            return
        }
        
        var totalSize: Int64 = 0
        var fileInfos: [(url: URL, date: Date, size: Int64)] = []
        
        for file in files {
            guard let attributes = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let date = attributes.contentModificationDate,
                  let size = attributes.fileSize else {
                continue
            }
            totalSize += Int64(size)
            fileInfos.append((file, date, Int64(size)))
        }
        
        // If under limit, no cleanup needed
        guard totalSize > maxCacheSize else { return }
        
        // Sort by date, oldest first
        fileInfos.sort { $0.date < $1.date }
        
        // Remove oldest files until under limit
        for fileInfo in fileInfos {
            guard totalSize > maxCacheSize else { break }
            
            try? fileManager.removeItem(at: fileInfo.url)
            let videoId = fileInfo.url.deletingPathExtension().lastPathComponent
            cachedVideos.removeValue(forKey: videoId)
            totalSize -= fileInfo.size
        }
    }
    
    func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        cachedVideos.removeAll()
        
        try? FileManager.default.removeItem(at: audioCacheDirectory)
        try? FileManager.default.createDirectory(at: audioCacheDirectory, withIntermediateDirectories: true)
        cachedAudio.removeAll()
    }
}

// MARK: - Video Preloader
@MainActor
final class VideoPreloader: ObservableObject {
    private var preloadedPlayers: [String: AVPlayer] = [:]
    private var preloadTasks: [String: Task<Void, Never>] = [:]
    
    func preload(videos: [Video], around currentIndex: Int) {
        // Guard against empty videos array
        guard !videos.isEmpty else { return }
        
        let preloadRange = max(0, currentIndex - 1)...min(videos.count - 1, currentIndex + 2)
        let videosToPreload = preloadRange.map { videos[$0] }
        
        // Cancel tasks for videos no longer in range
        let validIds = Set(videosToPreload.map { $0.id })
        for (id, task) in preloadTasks where !validIds.contains(id) {
            task.cancel()
            preloadTasks.removeValue(forKey: id)
        }
        
        // Start preloading videos in range
        for video in videosToPreload where preloadedPlayers[video.id] == nil {
            preloadTasks[video.id] = Task {
                await preloadVideo(video)
            }
        }
    }
    
    private func preloadVideo(_ video: Video) async {
        guard let streamURL = video.absoluteStreamURL else { return }
        
        // Try to get from cache or use remote URL
        let videoURL: URL
        if let cachedURL = await VideoCache.shared.getCachedURL(for: video.id) {
            videoURL = cachedURL
        } else {
            // Start caching in background, use remote URL for now
            Task {
                _ = try? await VideoCache.shared.cacheVideo(from: streamURL, videoId: video.id)
            }
            videoURL = streamURL
        }
        
        let playerItem = AVPlayerItem(url: videoURL)
        playerItem.preferredForwardBufferDuration = 3
        
        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = true
        
        await MainActor.run {
            preloadedPlayers[video.id] = player
        }
    }
    
    func getPlayer(for videoId: String) -> AVPlayer? {
        return preloadedPlayers[videoId]
    }
    
    func createPlayer(for video: Video) async -> AVPlayer {
        // Check cache first
        if let cachedURL = await VideoCache.shared.getCachedURL(for: video.id) {
            let player = AVPlayer(url: cachedURL)
            return player
        }
        
        guard let streamURL = video.absoluteStreamURL else {
            return AVPlayer()
        }
        
        // Cache in background
        Task {
            _ = try? await VideoCache.shared.cacheVideo(from: streamURL, videoId: video.id)
        }
        
        return AVPlayer(url: streamURL)
    }
    
    func clearPreloaded() {
        for (_, task) in preloadTasks {
            task.cancel()
        }
        preloadTasks.removeAll()
        
        for (_, player) in preloadedPlayers {
            player.pause()
        }
        preloadedPlayers.removeAll()
    }
}
