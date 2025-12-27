import SwiftUI
/**
 * ContentView is the main view of the app.
 * It displays the login view if the user is not authenticated,
 * otherwise it displays the video feed view.
 */
struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                VideoFeedView()
                    .environmentObject(authViewModel)
            } else {
                LoginView()
                    .environmentObject(authViewModel)
            }
        }
        .animation(.easeInOut, value: authViewModel.isAuthenticated)
    }
}
