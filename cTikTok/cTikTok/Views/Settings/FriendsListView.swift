import SwiftUI

struct FriendsListView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var friendToRemove: Friend?
    @State private var showingRemoveConfirm = false
    @State private var showingShareCode = false
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.friends.isEmpty {
                    emptyState
                } else {
                    friendsList
                }
            }
            .background(Color.black)
            .navigationTitle("Your Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert("Remove Friend?", isPresented: $showingRemoveConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    if let friend = friendToRemove {
                        Task {
                            await viewModel.removeFriend(friend)
                        }
                    }
                }
            } message: {
                if let friend = friendToRemove {
                    Text("Are you sure you want to remove @\(friend.username) from your friends? They won't be able to see your videos anymore.")
                }
            }
            .sheet(isPresented: $showingShareCode) {
                MyFriendCodeView(code: viewModel.myFriendCode) {
                    Task {
                        await viewModel.regenerateCode()
                    }
                }
            }
            .refreshable {
                await viewModel.loadFriends()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            
            Text("No Friends Yet")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Text("Share your code to get started!")
                .font(.subheadline)
                .foregroundStyle(.gray)
            
            Button {
                showingShareCode = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Your Code")
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var friendsList: some View {
        List {
            ForEach(viewModel.friends) { friend in
                FriendRow(friend: friend)
                    .listRowBackground(Color(.systemGray6).opacity(0.1))
            }
            .onDelete { indexSet in
                if let index = indexSet.first {
                    friendToRemove = viewModel.friends[index]
                    showingRemoveConfirm = true
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

struct FriendRow: View {
    let friend: Friend
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.gray)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.username)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text("Friends since \(friend.createdAt.formatted(.dateTime.month().day().year()))")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
