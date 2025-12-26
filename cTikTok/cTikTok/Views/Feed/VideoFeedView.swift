import SwiftUI
import AVKit

struct VideoFeedView: View {
    @StateObject private var viewModel = VideoFeedViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.videos.isEmpty {
                ProgressView()
                    .tint(.white)
            } else if viewModel.videos.isEmpty {
                EmptyFeedView()
            } else {
                videoFeed
            }
            
            // Overlay UI
            VStack {
                topBar
                Spacer()
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
    }
    
    // MARK: - Video Feed
    private var videoFeed: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.videos) { video in
                    VideoPlayerView(
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
        .ignoresSafeArea()
        .onChange(of: viewModel.currentVideoId) { _, newId in
            viewModel.handleVideoChange(newId)
        }
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Button {
                authViewModel.logout()
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
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
