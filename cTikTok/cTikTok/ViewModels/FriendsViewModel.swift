import Foundation
import Combine

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var incomingRequests: [FriendRequest] = []
    @Published var outgoingRequests: [FriendRequest] = []
    @Published var myFriendCode: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    var pendingRequestCount: Int {
        incomingRequests.count
    }
    
    init() {
        Task {
            await loadAll()
        }
    }
    
    func loadAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadFriends() }
            group.addTask { await self.loadIncomingRequests() }
            group.addTask { await self.loadOutgoingRequests() }
            group.addTask { await self.loadFriendCode() }
        }
    }
    
    func loadFriends() async {
        do {
            friends = try await APIService.shared.getFriends()
        } catch {
            print("Failed to load friends: \(error)")
        }
    }
    
    func loadIncomingRequests() async {
        do {
            incomingRequests = try await APIService.shared.getIncomingRequests()
        } catch {
            print("Failed to load incoming requests: \(error)")
        }
    }
    
    func loadOutgoingRequests() async {
        do {
            outgoingRequests = try await APIService.shared.getOutgoingRequests()
        } catch {
            print("Failed to load outgoing requests: \(error)")
        }
    }
    
    func loadFriendCode() async {
        do {
            myFriendCode = try await APIService.shared.getFriendCode()
        } catch {
            print("Failed to load friend code: \(error)")
        }
    }
    
    func sendFriendRequest(code: String) async {
        guard !code.isEmpty else {
            errorMessage = "Please enter a friend code"
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let response = try await APIService.shared.sendFriendRequest(code: code.uppercased())
            if response.friend != nil {
                // Auto-accepted (they had already sent us a request)
                successMessage = "You are now friends!"
                await loadFriends()
                await loadIncomingRequests()
            } else {
                successMessage = "Friend request sent!"
                await loadOutgoingRequests()
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func acceptRequest(_ request: FriendRequest) async {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await APIService.shared.acceptFriendRequest(id: request.id)
            await loadFriends()
            await loadIncomingRequests()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func rejectRequest(_ request: FriendRequest) async {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await APIService.shared.rejectFriendRequest(id: request.id)
            await loadIncomingRequests()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func removeFriend(_ friend: Friend) async {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await APIService.shared.removeFriend(id: friend.id)
            await loadFriends()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func regenerateCode() async {
        isLoading = true
        errorMessage = nil
        
        do {
            myFriendCode = try await APIService.shared.regenerateFriendCode()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}
