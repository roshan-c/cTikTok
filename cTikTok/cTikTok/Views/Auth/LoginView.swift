import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var username = ""
    @State private var password = ""
    @State private var showingRegister = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // Logo/Title
                VStack(spacing: 8) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.pink)
                    Text("cTikTok")
                        .font(.largeTitle.bold())
                }
                
                Spacer()
                
                // Form
                VStack(spacing: 16) {
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                    
                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button {
                        Task {
                            await authViewModel.login(username: username, password: password)
                        }
                    } label: {
                        if authViewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Sign In")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                    .disabled(authViewModel.isLoading)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Register link
                Button("Don't have an account? Sign Up") {
                    showingRegister = true
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding()
            .navigationDestination(isPresented: $showingRegister) {
                RegisterView()
            }
        }
    }
}
