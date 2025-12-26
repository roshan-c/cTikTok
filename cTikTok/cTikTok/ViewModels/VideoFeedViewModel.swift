import Foundation
import SwiftUI
import AVFoundation

@MainActor
final class VideoFeedViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var currentVideoId: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingSendSheet = false
    
    private let preloader = VideoPreloader()
    private var lastFetchTime: Date?
    
    var currentIndex: Int {
        guard let currentId = currentVideoId else { return 0 }
        return videos.firstIndex(where: { $0.id == currentId }) ?? 0
    }
    
    func loadVideos() {
        guard !isLoading else { return }
        
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let fetchedVideos = try await APIService.shared.getVideos(hours: 168) // Last 7 days
                videos = fetchedVideos
                lastFetchTime = Date()
                
                if currentVideoId == nil, let firstVideo = videos.first {
                    currentVideoId = firstVideo.id
                }
                
                // Preload videos around current index
                preloader.preload(videos: videos, around: currentIndex)
            } catch let error as APIError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
            
            isLoading = false
        }
    }
    
    func refresh() async {
        do {
            let fetchedVideos = try await APIService.shared.getVideos(hours: 168)
            videos = fetchedVideos
            lastFetchTime = Date()
            
            // Reset to first video if current is gone
            if let currentId = currentVideoId, !videos.contains(where: { $0.id == currentId }) {
                currentVideoId = videos.first?.id
            }
        } catch {
            // Silently fail on refresh
        }
    }
    
    func handleVideoChange(_ newId: String?) {
        guard let newId = newId else { return }
        
        // Update preloading
        if let index = videos.firstIndex(where: { $0.id == newId }) {
            preloader.preload(videos: videos, around: index)
        }
    }
    
    func getPlayer(for video: Video) async -> AVPlayer {
        if let player = preloader.getPlayer(for: video.id) {
            return player
        }
        return await preloader.createPlayer(for: video)
    }
    
    func isActive(_ video: Video) -> Bool {
        return video.id == currentVideoId
    }
}
