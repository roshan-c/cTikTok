import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentUser: User?
    
    init() {
        checkAuthentication()
    }
    
    func checkAuthentication() {
        if let token = KeychainHelper.shared.loadString(forKey: KeychainKeys.authToken),
           let userId = KeychainHelper.shared.loadString(forKey: KeychainKeys.userId),
           let username = KeychainHelper.shared.loadString(forKey: KeychainKeys.username) {
            self.currentUser = User(id: userId, username: username)
            self.isAuthenticated = true
        } else {
            self.isAuthenticated = false
            self.currentUser = nil
        }
    }
    
    func login(username: String, password: String) async {
        guard !username.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter username and password"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await APIService.shared.login(username: username, password: password)
            saveAuth(response: response)
            isAuthenticated = true
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func register(username: String, password: String, confirmPassword: String) async {
        guard !username.isEmpty else {
            errorMessage = "Please enter a username"
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "Passwords don't match"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await APIService.shared.register(username: username, password: password)
            saveAuth(response: response)
            isAuthenticated = true
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func saveAuth(response: AuthResponse) {
        _ = KeychainHelper.shared.save(response.token, forKey: KeychainKeys.authToken)
        _ = KeychainHelper.shared.save(response.user.id, forKey: KeychainKeys.userId)
        _ = KeychainHelper.shared.save(response.user.username, forKey: KeychainKeys.username)
        self.currentUser = response.user
    }
    
    func logout() {
        KeychainHelper.shared.clearAll()
        isAuthenticated = false
        currentUser = nil
    }
}
