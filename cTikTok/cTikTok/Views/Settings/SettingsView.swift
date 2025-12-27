import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var friendsViewModel = FriendsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAddFriend = false
    @State private var showingFriendRequests = false
    @State private var showingFriendsList = false
    @State private var showingMyCode = false
    
    var body: some View {
        NavigationStack {
            List {
                // Your Friend Code Section
                Section {
                    Button {
                        showingMyCode = true
                    } label: {
                        HStack {
                            Label("Your Friend Code", systemImage: "qrcode")
                            Spacer()
                            Text(friendsViewModel.myFriendCode)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.gray)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                    }
                } header: {
                    Text("Share Your Code")
                } footer: {
                    Text("Share this code with friends so they can add you")
                }
                .listRowBackground(Color(.systemGray6).opacity(0.1))
                
                // Friends Section
                Section {
                    Button {
                        showingAddFriend = true
                    } label: {
                        Label("Add Friend", systemImage: "person.badge.plus")
                    }
                    
                    Button {
                        showingFriendRequests = true
                    } label: {
                        HStack {
                            Label("Friend Requests", systemImage: "person.2")
                            Spacer()
                            if friendsViewModel.pendingRequestCount > 0 {
                                Text("\(friendsViewModel.pendingRequestCount)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.red)
                                    .clipShape(Capsule())
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                    }
                    
                    Button {
                        showingFriendsList = true
                    } label: {
                        HStack {
                            Label("Your Friends", systemImage: "person.3")
                            Spacer()
                            Text("\(friendsViewModel.friends.count)")
                                .foregroundStyle(.gray)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                    }
                } header: {
                    Text("Friends")
                }
                .listRowBackground(Color(.systemGray6).opacity(0.1))
                
                // Account Section
                Section {
                    Button(role: .destructive) {
                        authViewModel.logout()
                        dismiss()
                    } label: {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } header: {
                    Text("Account")
                } footer: {
                    if let username = authViewModel.currentUser?.username {
                        Text("Logged in as @\(username)")
                    }
                }
                .listRowBackground(Color(.systemGray6).opacity(0.1))
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Settings")
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
            .sheet(isPresented: $showingMyCode) {
                MyFriendCodeView(code: friendsViewModel.myFriendCode) {
                    Task {
                        await friendsViewModel.regenerateCode()
                    }
                }
            }
            .sheet(isPresented: $showingAddFriend) {
                AddFriendView(viewModel: friendsViewModel)
            }
            .sheet(isPresented: $showingFriendRequests) {
                FriendRequestsView(viewModel: friendsViewModel)
            }
            .sheet(isPresented: $showingFriendsList) {
                FriendsListView(viewModel: friendsViewModel)
            }
        }
        .preferredColorScheme(.dark)
    }
}
