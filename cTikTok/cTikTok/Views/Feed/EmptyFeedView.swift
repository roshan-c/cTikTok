import SwiftUI

struct EmptyFeedView: View {
    @State private var showingSettings = false
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            
            Text("No Videos Yet")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Text("Add friends to see what they share!\nPull down to refresh.")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
            
            Button {
                showingSettings = true
            } label: {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("Add Friends")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.blue)
                .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .padding()
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(authViewModel)
        }
    }
}
