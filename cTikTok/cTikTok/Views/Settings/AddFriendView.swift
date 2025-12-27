import SwiftUI

struct AddFriendView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var friendCode = ""
    @FocusState private var isCodeFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)
                    
                    Text("Add a Friend")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    
                    Text("Enter your friend's code to send them a request")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                VStack(spacing: 16) {
                    TextField("Friend Code", text: $friendCode)
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding()
                        .background(Color(.systemGray6).opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .focused($isCodeFieldFocused)
                        .onChange(of: friendCode) { _, newValue in
                            // Limit to 6 characters and uppercase
                            friendCode = String(newValue.uppercased().prefix(6))
                        }
                    
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    
                    if let success = viewModel.successMessage {
                        Text(success)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .padding(.horizontal, 20)
                
                Button {
                    Task {
                        await viewModel.sendFriendRequest(code: friendCode)
                        if viewModel.errorMessage == nil {
                            friendCode = ""
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                dismiss()
                            }
                        }
                    }
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Send Request")
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(friendCode.count == 6 ? .blue : .gray)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(friendCode.count != 6 || viewModel.isLoading)
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                viewModel.clearMessages()
                isCodeFieldFocused = true
            }
        }
        .preferredColorScheme(.dark)
    }
}
