import SwiftUI
import AVFoundation

struct SlideshowPlayerView: View {
    let video: Video
    let isActive: Bool
    let viewModel: VideoFeedViewModel
    
    @State private var currentImageIndex = 0
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isLoading = true
    @State private var loadedImages: [UIImage] = []
    @State private var isLiked = false
    @State private var isFavorited = false
    @State private var showHeartAnimation = false
    @State private var heartAnimationPosition: CGPoint = .zero
    
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
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if !loadedImages.isEmpty {
                    // Image carousel
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
                
                // Heart animation overlay
                if showHeartAnimation {
                    HeartAnimationView()
                        .position(heartAnimationPosition)
                }
                
                // Overlay UI
                VStack {
                    Spacer()
                    
                    HStack(alignment: .bottom) {
                        slideshowInfo
                        Spacer()
                        sideActions
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    
                    // Page indicator dots
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
    
    // MARK: - Page Indicator
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
    
    // MARK: - Slideshow Info
    private var slideshowInfo: some View {
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
            
            // Photo count indicator
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
    
    // MARK: - Side Actions
    private var sideActions: some View {
        VStack(spacing: 20) {
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
            
            // Download button
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
    
    // MARK: - Load Images
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
    
    // MARK: - Audio Setup
    private func setupAudio() {
        guard let audioURL = video.absoluteAudioURL else { return }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: audioURL)
                
                await MainActor.run {
                    do {
                        audioPlayer = try AVAudioPlayer(data: data)
                        audioPlayer?.numberOfLoops = -1 // Loop indefinitely
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
    
    // MARK: - Gestures & Actions
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
    
    private func toggleFavorite() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        Task {
            let scheduledDeletionAt = await viewModel.toggleFavorite(for: video)
            isFavorited.toggle()
            
            // Show toast if video will be deleted
            if let deletionDate = scheduledDeletionAt {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .full
                let timeString = formatter.localizedString(for: deletionDate, relativeTo: Date())
                viewModel.showToast("Video will be deleted \(timeString)")
            }
        }
    }
    
    private func saveSlideshow() {
        // Save all images to photo library
        for image in loadedImages {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}
