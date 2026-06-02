import UIKit

actor ImageLoader {
    static let shared = ImageLoader()

    private let session: URLSession
    private let cache = NSCache<NSURL, UIImage>()
    private let maxCachedImageCount = 20
    private let maxCacheBytes = 80 * 1024 * 1024

    init(session: URLSession = .shared) {
        self.session = session
        cache.countLimit = maxCachedImageCount
        cache.totalCostLimit = maxCacheBytes
    }

    func image(for url: URL) async -> UIImage? {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            return cached
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }

            let image = UIImage(data: data)
            guard let image else { return nil }

            let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? data.count
            cache.setObject(image, forKey: key, cost: cost)
            return image
        } catch {
            return nil
        }
    }
}
