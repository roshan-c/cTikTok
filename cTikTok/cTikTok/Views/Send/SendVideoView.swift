import SwiftUI

struct SendVideoView: View {
    @StateObject private var viewModel = SendVideoViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Instructions
                VStack(spacing: 8) {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 50))
                        .foregroundStyle(.pink)
                    
                    Text("Send a TikTok")
                        .font(.title2.bold())
                    
                    Text("Paste a TikTok link to send it")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                
                // URL Input
                VStack(spacing: 12) {
                    TextField("TikTok URL", text: $viewModel.tiktokURL)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    
                    // Paste button
                    Button {
                        if let clipboardString = UIPasteboard.general.string {
                            viewModel.tiktokURL = clipboardString
                        }
                    } label: {
                        Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                
                // Status
                if viewModel.showSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Video submitted! It will appear shortly.")
                            .font(.subheadline)
                    }
                    .padding()
                    .background(.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                if let error = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.subheadline)
                    }
                    .padding()
                    .background(.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                Spacer()
                
                // Submit Button
                Button {
                    Task {
                        await viewModel.submitVideo()
                    }
                } label: {
                    if viewModel.isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Send Video")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                .disabled(viewModel.isSubmitting || viewModel.tiktokURL.isEmpty)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Send Video")
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
}
