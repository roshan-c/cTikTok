import Foundation

@MainActor
final class SendVideoViewModel: ObservableObject {
    @Published var tiktokURL: String = ""
    @Published var message: String = ""
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
            let messageToSend = message.isEmpty ? nil : message
            _ = try await APIService.shared.submitVideo(url: tiktokURL, message: messageToSend)
            showSuccess = true
            tiktokURL = ""
            message = ""
            
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
        message = ""
        isSubmitting = false
        showSuccess = false
        errorMessage = nil
    }
}
