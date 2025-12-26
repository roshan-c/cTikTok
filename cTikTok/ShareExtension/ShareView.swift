import SwiftUI

struct ShareView: View {
    let sharedURL: String?
    let extensionContext: NSExtensionContext?
    
    @State private var status: ShareStatus = .idle
    @State private var errorMessage: String?
    
    enum ShareStatus {
        case idle, loading, success, error
    }
    
    private var isValidTikTokURL: Bool {
        guard let url = sharedURL else { return false }
        return url.contains("tiktok.com")
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                
                switch status {
                case .idle:
                    if isValidTikTokURL {
                        idleContent
                    } else {
                        invalidURLContent
                    }
                    
                case .loading:
                    ProgressView("Sending...")
                        .font(.headline)
                    
                case .success:
                    successContent
                    
                case .error:
                    errorContent
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Send TikTok")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Content Views
    
    private var idleContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.pink)
            
            Text("Send this TikTok?")
                .font(.headline)
            
            if let url = sharedURL {
                Text(url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                Task {
                    await sendToBackend()
                }
            } label: {
                Text("Send")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
        }
    }
    
    private var invalidURLContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            
            Text("Not a TikTok Link")
                .font(.headline)
            
            Text("Please share a valid TikTok URL")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var successContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            
            Text("Sent!")
                .font(.headline)
            
            Text("The video will be ready shortly")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            // Auto-dismiss after success
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        }
    }
    
    private var errorContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)
            
            Text("Failed to Send")
                .font(.headline)
            
            if let error = errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Try Again") {
                Task {
                    await sendToBackend()
                }
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - API Call
    
    private func sendToBackend() async {
        guard let url = sharedURL else {
            status = .error
            errorMessage = "No URL found"
            return
        }
        
        status = .loading
        
        // Get auth token from shared storage
        guard let sharedDefaults = UserDefaults(suiteName: AppConfig.appGroupIdentifier),
              let authToken = KeychainHelper.shared.loadString(forKey: KeychainKeys.authToken) else {
            status = .error
            errorMessage = "Not logged in. Please open the main app and log in first."
            return
        }
        
        // Prepare the request
        guard let requestURL = URL(string: "\(AppConfig.apiBaseURL)/api/videos") else {
            status = .error
            errorMessage = "Invalid API URL"
            return
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["url": url]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    status = .success
                } else if httpResponse.statusCode == 401 {
                    status = .error
                    errorMessage = "Session expired. Please log in again from the main app."
                } else {
                    status = .error
                    errorMessage = "Server error (\(httpResponse.statusCode))"
                }
            }
        } catch {
            status = .error
            errorMessage = error.localizedDescription
        }
    }
    
    private func dismiss() {
        extensionContext?.completeRequest(returningItems: [])
    }
}
