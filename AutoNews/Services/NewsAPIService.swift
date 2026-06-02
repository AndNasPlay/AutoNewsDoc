import Foundation

protocol NewsAPIService: Sendable {
    func fetchNews(page: Int, pageSize: Int) async throws -> NewsPage
}

struct LiveNewsAPIService: NewsAPIService {
    private let session: URLSession
    private let baseURL: URL

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://webapi.autodoc.ru/api/news")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    func fetchNews(page: Int, pageSize: Int) async throws -> NewsPage {
        guard page > 0, pageSize > 0 else {
            throw NewsAPIError.invalidURL
        }

        let url = baseURL.appendingPathComponent("\(page)/\(pageSize)")
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NewsAPIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw NewsAPIError.httpStatus(httpResponse.statusCode)
        }

        return try NewsPage.decode(from: data)
    }
}
