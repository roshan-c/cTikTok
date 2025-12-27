import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let video: Video
    let isActive: Bool
    let viewModel: VideoFeedViewModel
    
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var isLiked = false
    @State private var isFavorited = false
    @State private var showHeartAnimation = false
    @State private var heartAnimationPosition: CGPoint = .zero
    @State private var progress: Double = 0
    @State private var duration: Double = 1
    @State private var isSpedUp = false
    @State private var timeObserver: Any?
    @State private var observerPlayer: AVPlayer?  // Track which player owns the observer
    @State private var loopObserver: NSObjectProtocol?  // Track loop notification observer
    
    init(video: Video, isActive: Bool, viewModel: VideoFeedViewModel) {
        self.video = video
        self.isActive = isActive
        self.viewModel = viewModel
        self._isFavorited = State(initialValue: video.isFavoritedValue)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                
                // Video Player with gesture overlay
                if let player = player {
                    ZStack {
                        CustomVideoPlayer(player: player)
                        
                        // Gesture overlay for tap interactions
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                TapGesture(count: 2)
                                    .onEnded {
                                        doubleTapLike(in: geometry)
                                    }
                            )
                            .simultaneousGesture(
                                TapGesture(count: 1)
                                    .onEnded {
                                        togglePlayback()
                                    }
                            )
                    }
                }
                
                // Loading indicator
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                
                // Heart animation overlay
                if showHeartAnimation {
                    HeartAnimationView()
                        .position(heartAnimationPosition)
                }
                

                
                // Video Info Overlay
                VStack {
                    Spacer()
                    
                    HStack(alignment: .bottom) {
                        videoInfo
                        Spacer()
                        sideActions
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    
                    // Progress bar at the very bottom
                    ProgressBar(progress: progress)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 34)
                }
            }
        }
        .task {
            await setupPlayer()
        }
        .onChange(of: isActive) { _, newValue in
            handleActiveChange(newValue)
        }
        .onDisappear {
            cleanupPlayer()
        }
    }
    
    // MARK: - Progress Bar
    struct ProgressBar: View {
        let progress: Double
        
        var body: some View {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 3)
                    
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: geometry.size.width * CGFloat(min(max(progress, 0), 1)), height: 3)
                }
            }
            .frame(height: 3)
            .clipShape(Capsule())
        }
    }
    
    // MARK: - Heart Animation
    struct HeartAnimationView: View {
        @State private var scale: CGFloat = 0
        @State private var opacity: Double = 1
        
        var body: some View {
            Image(systemName: "heart.fill")
                .font(.system(size: 100))
                .foregroundStyle(.red)
                .shadow(color: .black.opacity(0.3), radius: 10)
                .scaleEffect(scale)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        scale = 1.2
                    }
                    withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
                        scale = 1.0
                    }
                    withAnimation(.easeOut(duration: 0.4).delay(0.6)) {
                        opacity = 0
                    }
                }
        }
    }
    
    // MARK: - Video Info
    private var videoInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Message bubble (if present)
            if let message = video.message, !message.isEmpty {
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            if let sender = video.senderUsername {
                Text("@\(sender)")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            
            if let author = video.tiktokAuthor {
                Text("From: \(author.hasPrefix("@") ? author : "@\(author)")")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            
            if let desc = video.tiktokDescription, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: 250, alignment: .leading)
    }
    
    // MARK: - Side Actions
    private var sideActions: some View {
        VStack(spacing: 20) {
            // Speed button
            Button {
                toggleSpeed()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: isSpedUp ? "gauge.with.dots.needle.67percent" : "gauge.with.dots.needle.33percent")
                        .font(.title)
                        .foregroundStyle(isSpedUp ? .yellow : .white)
                        .scaleEffect(isSpedUp ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSpedUp)
                    Text(isSpedUp ? "2x" : "1x")
                        .font(.caption2)
                }
                .foregroundStyle(.white)
            }
            
            // Like button
            Button {
                toggleLike()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.title)
                        .foregroundStyle(isLiked ? .red : .white)
                        .scaleEffect(isLiked ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLiked)
                    Text("Like")
                        .font(.caption2)
                }
                .foregroundStyle(.white)
            }
            
            // Favorite/Bookmark button
            Button {
                toggleFavorite()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: isFavorited ? "bookmark.fill" : "bookmark")
                        .font(.title)
                        .foregroundStyle(isFavorited ? .yellow : .white)
                        .scaleEffect(isFavorited ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFavorited)
                    Text(isFavorited ? "Saved" : "Save")
                        .font(.caption2)
                }
                .foregroundStyle(.white)
            }
            
            // Share/Download button
            Button {
                shareVideo()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title)
                    Text("Download")
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
        
        await MainActor.run {
            self.player = newPlayer
            self.isLoading = false
            
            // Setup time observer for progress
            setupTimeObserver(for: newPlayer)
            
            // Setup looping notification
            setupLooping(for: newPlayer)
            
            if isActive {
                newPlayer.seek(to: .zero)
                newPlayer.play()
            }
        }
    }
    
    private func setupTimeObserver(for player: AVPlayer) {
        // Remove existing observer from the correct player
        if let observer = timeObserver, let oldPlayer = observerPlayer {
            oldPlayer.removeTimeObserver(observer)
            timeObserver = nil
            observerPlayer = nil
        }
        
        // Add periodic time observer
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            guard let item = player.currentItem else { return }
            let currentTime = CMTimeGetSeconds(time)
            let totalDuration = CMTimeGetSeconds(item.duration)
            
            if totalDuration.isFinite && totalDuration > 0 {
                self.duration = totalDuration
                self.progress = currentTime / totalDuration
            }
        }
        observerPlayer = player
    }
    
    private func setupLooping(for player: AVPlayer) {
        // Remove existing observer if any
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
        
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            // Auto-loop: seek to beginning and continue playing
            player.seek(to: .zero)
            player.play()
        }
    }
    
    private func cleanupPlayer() {
        // Remove time observer from the correct player instance
        if let observer = timeObserver, let oldPlayer = observerPlayer {
            oldPlayer.removeTimeObserver(observer)
        }
        // Remove loop observer
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
        player?.pause()
        timeObserver = nil
        observerPlayer = nil
    }
    
    private func handleActiveChange(_ isActive: Bool) {
        if isActive {
            player?.seek(to: .zero)
            player?.play()
        } else {
            player?.pause()
            // Reset speed when leaving video
            if isSpedUp {
                isSpedUp = false
            }
        }
    }
    
    // MARK: - Gestures
    private func togglePlayback() {
        guard let player = player else { return }
        
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }
    
    private func doubleTapLike(in geometry: GeometryProxy) {
        // Show heart animation at center
        heartAnimationPosition = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        showHeartAnimation = true
        
        // Set liked state
        if !isLiked {
            isLiked = true
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
        
        // Hide animation after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showHeartAnimation = false
        }
    }
    
    private func toggleLike() {
        isLiked.toggle()
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func toggleSpeed() {
        isSpedUp.toggle()
        if isSpedUp {
            player?.rate = 2.0
        } else {
            if player?.timeControlStatus == .playing {
                player?.rate = 1.0
            }
        }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func toggleFavorite() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        Task {
            let scheduledDeletionAt = await viewModel.toggleFavorite(for: video)
            isFavorited.toggle()
            
            // Show toast if video will be deleted
            if let deletionDate = scheduledDeletionAt {
                let timeString = DateFormatters.relative.localizedString(for: deletionDate, relativeTo: Date())
                viewModel.showToast("Video will be deleted \(timeString)")
            }
        }
    }
    
    private func shareVideo() {
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

// MARK: - Custom Video Player (without default controls)
struct CustomVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}
