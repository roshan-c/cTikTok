import SwiftUI
import AVKit

struct FavoritesView: View {
    @StateObject private var viewModel = FavoritesViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.videos.isEmpty {
                    ProgressView()
                        .tint(.white)
                } else if viewModel.isEmpty {
                    emptyState
                } else {
                    videoFeed
                }
                
                // Toast overlay
                if let toast = viewModel.toastMessage {
                    VStack {
                        Spacer()
                        ToastView(message: toast)
                            .padding(.bottom, 100)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut, value: viewModel.toastMessage)
                }
            }
            .navigationTitle("Saved Videos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .onAppear {
            viewModel.loadFavorites()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "bookmark")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            
            Text("No Saved Videos")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            
            Text("Tap the bookmark icon on any video to save it here forever.")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Video Feed
    private var videoFeed: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.videos) { video in
                    FavoritesVideoPlayerWrapper(
                        video: video,
                        isActive: viewModel.isActive(video),
                        viewModel: viewModel
                    )
                    .containerRelativeFrame([.horizontal, .vertical])
                    .id(video.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $viewModel.currentVideoId)
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: viewModel.currentVideoId) { _, newId in
            viewModel.handleVideoChange(newId)
        }
    }
}

// MARK: - Video Player Wrapper for Favorites
struct FavoritesVideoPlayerWrapper: View {
    let video: Video
    let isActive: Bool
    let viewModel: FavoritesViewModel
    
    var body: some View {
        if video.isSlideshow {
            FavoritesSlideshowPlayerView(
                video: video,
                isActive: isActive,
                viewModel: viewModel
            )
        } else {
            FavoritesVideoPlayerView(
                video: video,
                isActive: isActive,
                viewModel: viewModel
            )
        }
    }
}

// MARK: - Toast View
struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.8))
            .clipShape(Capsule())
    }
}

// MARK: - Favorites Video Player View
struct FavoritesVideoPlayerView: View {
    let video: Video
    let isActive: Bool
    let viewModel: FavoritesViewModel
    
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var isLiked = false
    @State private var showHeartAnimation = false
    @State private var heartAnimationPosition: CGPoint = .zero
    @State private var progress: Double = 0
    @State private var duration: Double = 1
    @State private var isSpedUp = false
    @State private var timeObserver: Any?
    @State private var observerPlayer: AVPlayer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                
                if let player = player {
                    ZStack {
                        CustomVideoPlayer(player: player)
                        
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
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                
                if showHeartAnimation {
                    HeartAnimationView()
                        .position(heartAnimationPosition)
                }
                
                VStack {
                    Spacer()
                    
                    HStack(alignment: .bottom) {
                        videoInfo
                        Spacer()
                        sideActions
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    
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
    
    private var videoInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
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
    
    private var sideActions: some View {
        VStack(spacing: 20) {
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
            
            // Unfavorite button
            Button {
                unfavorite()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "bookmark.slash.fill")
                        .font(.title)
                    Text("Remove")
                        .font(.caption2)
                }
                .foregroundStyle(.white)
            }
            
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
    
    private func setupPlayer() async {
        isLoading = true
        
        let newPlayer = await viewModel.getPlayer(for: video)
        
        await MainActor.run {
            self.player = newPlayer
            self.isLoading = false
            
            setupTimeObserver(for: newPlayer)
            setupLooping(for: newPlayer)
            
            if isActive {
                newPlayer.seek(to: .zero)
                newPlayer.play()
            }
        }
    }
    
    private func setupTimeObserver(for player: AVPlayer) {
        if let observer = timeObserver, let oldPlayer = observerPlayer {
            oldPlayer.removeTimeObserver(observer)
            timeObserver = nil
            observerPlayer = nil
        }
        
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
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
    }
    
    private func cleanupPlayer() {
        if let observer = timeObserver, let oldPlayer = observerPlayer {
            oldPlayer.removeTimeObserver(observer)
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
            if isSpedUp {
                isSpedUp = false
            }
        }
    }
    
    private func togglePlayback() {
        guard let player = player else { return }
        
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }
    
    private func doubleTapLike(in geometry: GeometryProxy) {
        heartAnimationPosition = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        showHeartAnimation = true
        
        if !isLiked {
            isLiked = true
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
        
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
    
    private func unfavorite() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        Task {
            let scheduledDeletionAt = await viewModel.unfavorite(video)
            
            if let deletionDate = scheduledDeletionAt {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .full
                let timeString = formatter.localizedString(for: deletionDate, relativeTo: Date())
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

// MARK: - Favorites Slideshow Player View
struct FavoritesSlideshowPlayerView: View {
    let video: Video
    let isActive: Bool
    let viewModel: FavoritesViewModel
    
    @State private var currentImageIndex = 0
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isLoading = true
    @State private var loadedImages: [UIImage] = []
    @State private var isLiked = false
    @State private var showHeartAnimation = false
    @State private var heartAnimationPosition: CGPoint = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if !loadedImages.isEmpty {
                    TabView(selection: $currentImageIndex) {
                        ForEach(0..<loadedImages.count, id: \.self) { index in
                            Image(uiImage: loadedImages[index])
                                .resizable()
                                .scaledToFit()
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .gesture(
                        TapGesture(count: 2)
                            .onEnded {
                                doubleTapLike(in: geometry)
                            }
                    )
                }
                
                if showHeartAnimation {
                    HeartAnimationView()
                        .position(heartAnimationPosition)
                }
                
                VStack {
                    Spacer()
                    
                    HStack(alignment: .bottom) {
                        slideshowInfo
                        Spacer()
                        sideActions
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    
                    if loadedImages.count > 1 {
                        PageIndicator(currentIndex: currentImageIndex, total: loadedImages.count)
                            .padding(.bottom, 34)
                    }
                }
            }
        }
        .task {
            await loadImages()
        }
        .onChange(of: isActive) { _, newValue in
            handleActiveChange(newValue)
        }
        .onDisappear {
            audioPlayer?.stop()
        }
    }
    
    struct PageIndicator: View {
        let currentIndex: Int
        let total: Int
        
        var body: some View {
            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { index in
                    Circle()
                        .fill(index == currentIndex ? Color.white : Color.white.opacity(0.4))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.3))
            .clipShape(Capsule())
        }
    }
    
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
    
    private var slideshowInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            
            if let count = video.imageCount, count > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle")
                    Text("\(currentImageIndex + 1)/\(count)")
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: 250, alignment: .leading)
    }
    
    private var sideActions: some View {
        VStack(spacing: 20) {
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
            
            // Unfavorite button
            Button {
                unfavorite()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "bookmark.slash.fill")
                        .font(.title)
                    Text("Remove")
                        .font(.caption2)
                }
                .foregroundStyle(.white)
            }
            
            Button {
                saveSlideshow()
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
    
    private func loadImages() async {
        isLoading = true
        
        let urls = video.absoluteImageURLs
        var images: [UIImage] = []
        
        for url in urls {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    images.append(image)
                }
            } catch {
                print("Failed to load image: \(error)")
            }
        }
        
        await MainActor.run {
            loadedImages = images
            isLoading = false
            
            if isActive {
                setupAudio()
            }
        }
    }
    
    private func setupAudio() {
        guard let audioURL = video.absoluteAudioURL else { return }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: audioURL)
                
                await MainActor.run {
                    do {
                        audioPlayer = try AVAudioPlayer(data: data)
                        audioPlayer?.numberOfLoops = -1
                        audioPlayer?.play()
                    } catch {
                        print("Failed to create audio player: \(error)")
                    }
                }
            } catch {
                print("Failed to download audio: \(error)")
            }
        }
    }
    
    private func handleActiveChange(_ isActive: Bool) {
        if isActive {
            currentImageIndex = 0
            setupAudio()
        } else {
            audioPlayer?.stop()
            audioPlayer = nil
        }
    }
    
    private func doubleTapLike(in geometry: GeometryProxy) {
        heartAnimationPosition = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        showHeartAnimation = true
        
        if !isLiked {
            isLiked = true
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showHeartAnimation = false
        }
    }
    
    private func toggleLike() {
        isLiked.toggle()
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func unfavorite() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        Task {
            let scheduledDeletionAt = await viewModel.unfavorite(video)
            
            if let deletionDate = scheduledDeletionAt {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .full
                let timeString = formatter.localizedString(for: deletionDate, relativeTo: Date())
                viewModel.showToast("Video will be deleted \(timeString)")
            }
        }
    }
    
    private func saveSlideshow() {
        for image in loadedImages {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}
