import UIKit
import SwiftUI
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        extractSharedURL { [weak self] url in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                let shareView = ShareView(
                    sharedURL: url,
                    extensionContext: self.extensionContext
                )
                
                let hostingController = UIHostingController(rootView: shareView)
                self.addChild(hostingController)
                self.view.addSubview(hostingController.view)
                
                hostingController.view.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    hostingController.view.topAnchor.constraint(equalTo: self.view.topAnchor),
                    hostingController.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
                    hostingController.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                    hostingController.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
                ])
                
                hostingController.didMove(toParent: self)
            }
        }
    }
    
    private func extractSharedURL(completion: @escaping (String?) -> Void) {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completion(nil)
            return
        }
        
        for item in extensionItems {
            guard let attachments = item.attachments else { continue }
            
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { (data, error) in
                        if let url = data as? URL {
                            completion(url.absoluteString)
                        } else {
                            completion(nil)
                        }
                    }
                    return
                }
                
                // Also handle plain text (in case TikTok shares as text)
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { (data, error) in
                        if let text = data as? String, text.contains("tiktok.com") {
                            completion(text)
                        } else {
                            completion(nil)
                        }
                    }
                    return
                }
            }
        }
        completion(nil)
    }
}
