import SwiftUI
import AVKit

struct SlideshowPlayerView: View {
    let video: Video
    let isActive: Bool
    let viewModel: VideoFeedViewModel
    
    @State private var currentIndex = 0
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isLoading = true
    @State private var isLiked = false
    @State private var showHeartAnimation = false
    @State private var heartAnimationPosition: CGPoint = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                
                // Image carousel
                if !video.absoluteImageURLs.isEmpty {
                    TabView(selection: $currentIndex) {
                        ForEach(Array(video.absoluteImageURLs.enumerated()), id: \.offset) { index, url in
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .tint(.white)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                case .failure:
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundStyle(.gray)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                
                // Overlay content
                VStack {
                    Spacer()
                    
                    HStack(alignment: .bottom) {
                        videoInfo
                        Spacer()
                        sideActions
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    
                    // Page indicator dots
                    PageIndicator(
                        currentIndex: currentIndex,
                        totalCount: video.imageCount ?? video.absoluteImageURLs.count
                    )
                    .padding(.bottom, 34)
                }
            }
        }
        .task {
            await setupAudio()
        }
        .onChange(of: isActive) { _, newValue in
            handleActiveChange(newValue)
        }
        .onDisappear {
            cleanupAudio()
        }
    }
    
    // MARK: - Page Indicator
    struct PageIndicator: View {
        let currentIndex: Int
        let totalCount: Int
        
        var body: some View {
            HStack(spacing: 6) {
                ForEach(0..<totalCount, id: \.self) { index in
                    Circle()
                        .fill(index == currentIndex ? Color.white : Color.white.opacity(0.4))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial.opacity(0.5))
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
            
            // Image counter
            VStack(spacing: 4) {
                Image(systemName: "photo.on.rectangle")
                    .font(.title)
                Text("\(currentIndex + 1)/\(video.imageCount ?? video.absoluteImageURLs.count)")
                    .font(.caption2)
            }
            .foregroundStyle(.white)
        }
    }
    
    // MARK: - Audio Setup
    private func setupAudio() async {
        isLoading = true
        
        guard let audioURL = video.absoluteAudioURL else {
            isLoading = false
            return
        }
        
        do {
            // Download audio to temp file
            let (data, _) = try await URLSession.shared.data(from: audioURL)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(video.id)_audio.mp3")
            try data.write(to: tempURL)
            
            await MainActor.run {
                do {
                    audioPlayer = try AVAudioPlayer(contentsOf: tempURL)
                    audioPlayer?.numberOfLoops = -1 // Loop indefinitely
                    audioPlayer?.prepareToPlay()
                    
                    if isActive {
                        audioPlayer?.play()
                    }
                } catch {
                    print("Failed to create audio player: \(error)")
                }
                isLoading = false
            }
        } catch {
            print("Failed to download audio: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func cleanupAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    private func handleActiveChange(_ isActive: Bool) {
        if isActive {
            audioPlayer?.play()
        } else {
            audioPlayer?.pause()
        }
    }
    
    // MARK: - Gestures
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
}
