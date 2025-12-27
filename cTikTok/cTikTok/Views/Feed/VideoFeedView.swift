import SwiftUI
import AVKit

struct VideoFeedView: View {
    @StateObject private var viewModel = VideoFeedViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingSettings = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.videos.isEmpty {
                ProgressView()
                    .tint(.white)
            } else if viewModel.videos.isEmpty {
                EmptyFeedView()
                    .environmentObject(authViewModel)
            } else {
                videoFeed
            }
            
            // Overlay UI
            VStack {
                topBar
                Spacer()
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
        .onAppear {
            viewModel.loadVideos()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .sheet(isPresented: $viewModel.showingSendSheet) {
            SendVideoView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(authViewModel)
        }
    }
    
    // MARK: - Video Feed
    private var videoFeed: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.videos) { video in
                    Group {
                        if video.isSlideshow {
                            SlideshowPlayerView(
                                video: video,
                                isActive: viewModel.isActive(video),
                                viewModel: viewModel
                            )
                        } else {
                            VideoPlayerView(
                                video: video,
                                isActive: viewModel.isActive(video),
                                viewModel: viewModel
                            )
                        }
                    }
                    .containerRelativeFrame([.horizontal, .vertical])
                    .id(video.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $viewModel.currentVideoId)
        .ignoresSafeArea()
        .onChange(of: viewModel.currentVideoId) { _, newId in
            viewModel.handleVideoChange(newId)
        }
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            
            Spacer()
            
            Text("cTikTok")
                .font(.headline)
                .foregroundStyle(.white)
            
            Spacer()
            
            Button {
                viewModel.showingSendSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.black.opacity(0.6), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
