import UIKit

/// Actor-based image cache using NSCache for thread-safe, memory-efficient caching
actor ImageCache {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSURL, UIImage>()
    private var inFlightRequests: [URL: Task<UIImage?, Never>] = [:]
    
    private init() {
        cache.countLimit = 100  // Max 100 images
        cache.totalCostLimit = 50 * 1024 * 1024  // 50MB
    }
    
    /// Get a single image, using cache if available, otherwise downloading
    func image(for url: URL) async -> UIImage? {
        // Check cache first
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        
        // Check if already downloading
        if let existing = inFlightRequests[url] {
            return await existing.value
        }
        
        // Start download
        let task = Task<UIImage?, Never> {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { return nil }
                cache.setObject(image, forKey: url as NSURL, cost: data.count)
                return image
            } catch {
                print("[ImageCache] Failed to load image from \(url): \(error)")
                return nil
            }
        }
        
        inFlightRequests[url] = task
        let result = await task.value
        inFlightRequests.removeValue(forKey: url)
        
        return result
    }
    
    /// Load multiple images in parallel, returning them in order
    func loadImages(from urls: [URL]) async -> [UIImage] {
        await withTaskGroup(of: (Int, UIImage?).self) { group in
            for (index, url) in urls.enumerated() {
                group.addTask {
                    let image = await self.image(for: url)
                    return (index, image)
                }
            }
            
            var results: [(Int, UIImage)] = []
            for await (index, image) in group {
                if let image = image {
                    results.append((index, image))
                }
            }
            
            // Sort by original index to maintain order
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
    
    /// Clear the entire cache
    func clearCache() {
        cache.removeAllObjects()
        for (_, task) in inFlightRequests {
            task.cancel()
        }
        inFlightRequests.removeAll()
    }
    
    /// Remove a specific image from cache
    func removeImage(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }
}
