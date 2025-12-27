import SwiftUI
import UIKit

struct MyFriendCodeView: View {
    let code: String
    let onRegenerate: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingRegenerateConfirm = false
    @State private var copied = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    
                    Text("Your Friend Code")
                        .font(.title2)
                        .foregroundStyle(.gray)
                    
                    Text(code)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .tracking(8)
                    
                    Text("Share this code with friends so they can send you a friend request")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = code
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copied = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            Text(copied ? "Copied!" : "Copy Code")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    ShareLink(item: "Add me on cTikTok! My friend code is: \(code)") {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Code")
                        }
                        .font(.headline)
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button {
                        showingRegenerateConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Generate New Code")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
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
            .alert("Generate New Code?", isPresented: $showingRegenerateConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Generate", role: .destructive) {
                    onRegenerate()
                }
            } message: {
                Text("Your current code will stop working. Friends who have your old code will need the new one.")
            }
        }
        .preferredColorScheme(.dark)
    }
}
