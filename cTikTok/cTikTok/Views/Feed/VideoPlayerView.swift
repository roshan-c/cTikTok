import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let video: Video
    let isActive: Bool
    let viewModel: VideoFeedViewModel
    
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var showReplay = false
    
    var body: some View {
        ZStack {
            Color.black
            
            if let player = player {
                VideoPlayer(player: player)
                    .disabled(true) // Disable default controls
                    .onTapGesture {
                        togglePlayback()
                    }
            }
            
            if isLoading {
                ProgressView()
                    .tint(.white)
            }
            
            if showReplay {
                Button {
                    replayVideo()
                } label: {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            
            // Video Info Overlay
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    videoInfo
                    Spacer()
                    sideActions
                }
                .padding()
                .padding(.bottom, 40)
            }
        }
        .task {
            await setupPlayer()
        }
        .onChange(of: isActive) { _, newValue in
            handleActiveChange(newValue)
        }
        .onDisappear {
            player?.pause()
        }
    }
    
    // MARK: - Video Info
    private var videoInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let sender = video.senderUsername {
                Text("@\(sender)")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            
            if let author = video.tiktokAuthor {
                Text("From: @\(author)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            
            if let desc = video.tiktokDescription, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
            }
            
            Text(video.createdAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: 250, alignment: .leading)
    }
    
    // MARK: - Side Actions
    private var sideActions: some View {
        VStack(spacing: 20) {
            // Like button (visual only for now)
            Button {
                // Future: implement likes
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.title)
                    Text("Like")
                        .font(.caption2)
                }
                .foregroundStyle(.white)
            }
            
            // Share/Save button
            Button {
                shareVideo()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title)
                    Text("Save")
                        .font(.caption2)
                }
                .foregroundStyle(.white)
            }
        }
    }
    
    // MARK: - Player Setup
    private func setupPlayer() async {
        isLoading = true
        
        let newPlayer = await viewModel.getPlayer(for: video)
        
        // Setup looping
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayer.currentItem,
            queue: .main
        ) { _ in
            showReplay = true
        }
        
        await MainActor.run {
            self.player = newPlayer
            self.isLoading = false
            
            if isActive {
                newPlayer.seek(to: .zero)
                newPlayer.play()
            }
        }
    }
    
    private func handleActiveChange(_ isActive: Bool) {
        if isActive {
            showReplay = false
            player?.seek(to: .zero)
            player?.play()
        } else {
            player?.pause()
        }
    }
    
    private func togglePlayback() {
        guard let player = player else { return }
        
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            if showReplay {
                replayVideo()
            } else {
                player.play()
            }
        }
    }
    
    private func replayVideo() {
        showReplay = false
        player?.seek(to: .zero)
        player?.play()
    }
    
    private func shareVideo() {
        // Save to camera roll functionality
        guard let url = video.absoluteStreamURL else { return }
        
        Task {
            do {
                let localURL = try await VideoCache.shared.cacheVideo(from: url, videoId: video.id)
                
                await MainActor.run {
                    let activityVC = UIActivityViewController(
                        activityItems: [localURL],
                        applicationActivities: nil
                    )
                    
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootVC = window.rootViewController {
                        rootVC.present(activityVC, animated: true)
                    }
                }
            } catch {
                print("Failed to share video: \(error)")
            }
        }
    }
}
