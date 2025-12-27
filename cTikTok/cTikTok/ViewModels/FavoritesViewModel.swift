import Foundation
import SwiftUI
import AVFoundation

@MainActor
final class FavoritesViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var currentVideoId: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var toastMessage: String?
    
    private let preloader = VideoPreloader()
    
    var currentIndex: Int {
        guard let currentId = currentVideoId else { return 0 }
        return videos.firstIndex(where: { $0.id == currentId }) ?? 0
    }
    
    var isEmpty: Bool {
        !isLoading && videos.isEmpty
    }
    
    func loadFavorites() {
        guard !isLoading else { return }
        
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let fetchedVideos = try await APIService.shared.getFavorites()
                videos = fetchedVideos
                
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
            let fetchedVideos = try await APIService.shared.getFavorites()
            videos = fetchedVideos
            
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
    
    // MARK: - Favorites
    
    func unfavorite(_ video: Video) async -> Date? {
        let videoId = video.id
        
        do {
            let response = try await APIService.shared.unfavoriteVideo(id: videoId)
            
            // Remove from local list
            videos.removeAll { $0.id == videoId }
            
            // Reset current video if needed
            if currentVideoId == videoId {
                currentVideoId = videos.first?.id
            }
            
            return response.scheduledDeletionAt
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    func showToast(_ message: String) {
        toastMessage = message
        
        // Auto-dismiss after 3 seconds
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }
}
