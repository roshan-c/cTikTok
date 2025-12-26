import Foundation

@MainActor
final class SendVideoViewModel: ObservableObject {
    @Published var tiktokURL: String = ""
    @Published var isSubmitting = false
    @Published var showSuccess = false
    @Published var errorMessage: String?
    
    var isValidURL: Bool {
        guard let url = URL(string: tiktokURL) else { return false }
        let host = url.host?.lowercased() ?? ""
        return host.contains("tiktok.com")
    }
    
    func submitVideo() async {
        guard isValidURL else {
            errorMessage = "Please enter a valid TikTok URL"
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        
        do {
            _ = try await APIService.shared.submitVideo(url: tiktokURL)
            showSuccess = true
            tiktokURL = ""
            
            // Auto-dismiss success after delay
            try? await Task.sleep(for: .seconds(2))
            showSuccess = false
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isSubmitting = false
    }
    
    func reset() {
        tiktokURL = ""
        isSubmitting = false
        showSuccess = false
        errorMessage = nil
    }
}
