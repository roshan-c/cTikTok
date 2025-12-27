import SwiftUI

struct FriendRequestsView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if !viewModel.incomingRequests.isEmpty {
                    Section {
                        ForEach(viewModel.incomingRequests) { request in
                            IncomingRequestRow(request: request, viewModel: viewModel)
                        }
                    } header: {
                        Text("Incoming Requests")
                    }
                    .listRowBackground(Color(.systemGray6).opacity(0.1))
                }
                
                if !viewModel.outgoingRequests.isEmpty {
                    Section {
                        ForEach(viewModel.outgoingRequests) { request in
                            OutgoingRequestRow(request: request)
                        }
                    } header: {
                        Text("Sent Requests")
                    }
                    .listRowBackground(Color(.systemGray6).opacity(0.1))
                }
                
                if viewModel.incomingRequests.isEmpty && viewModel.outgoingRequests.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "tray")
                                .font(.system(size: 40))
                                .foregroundStyle(.gray)
                            
                            Text("No Pending Requests")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            Text("Friend requests you receive will appear here")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Friend Requests")
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
            .refreshable {
                await viewModel.loadIncomingRequests()
                await viewModel.loadOutgoingRequests()
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct IncomingRequestRow: View {
    let request: FriendRequest
    @ObservedObject var viewModel: FriendsViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(request.fromUser?.username ?? "Unknown")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text("Wants to be your friend")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button {
                    Task {
                        await viewModel.rejectRequest(request)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.red)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                Button {
                    Task {
                        await viewModel.acceptRequest(request)
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.green)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

struct OutgoingRequestRow: View {
    let request: FriendRequest
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(request.toUser?.username ?? "Unknown")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text("Request pending")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            
            Spacer()
            
            Image(systemName: "clock")
                .foregroundStyle(.orange)
        }
        .padding(.vertical, 4)
    }
}
