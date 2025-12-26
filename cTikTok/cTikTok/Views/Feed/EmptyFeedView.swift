import SwiftUI

struct EmptyFeedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.slash")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            
            Text("No Videos Yet")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Text("Videos sent to you will appear here.\nPull down to refresh!")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
