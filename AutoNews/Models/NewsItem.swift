import Foundation

nonisolated struct NewsItem: Hashable, Sendable {
    let id: Int
    let title: String
    let description: String
    let publishedDate: Date
    let url: String
    let fullUrl: String
    let titleImageUrl: String?
    let categoryType: String
    
    var imageURL: URL? {
        guard let string = titleImageUrl, !string.isEmpty else { return nil }
        return URL(string: string)
    }

    var hasImage: Bool {
        guard let titleImageUrl else { return false }
        return !titleImageUrl.isEmpty
    }

    var articleURL: URL? {
        URL(string: fullUrl)
    }
}

nonisolated struct NewsPage: Sendable {
    let news: [NewsItem]
    let totalCount: Int
}

nonisolated private struct NewsPageDTO: Decodable {
    let news: [NewsItemDTO]
    let totalCount: Int
}

private struct NewsItemDTO: Decodable {
    let id: Int
    let title: String
    let description: String
    let publishedDate: String
    let url: String
    let fullUrl: String
    let titleImageUrl: String?
    let categoryType: String
    
    func makeNewsItem() throws -> NewsItem {
        guard let date = NewsDateFormatter.parse(publishedDate) else {
            throw NewsAPIError.invalidDate(publishedDate)
        }
        return NewsItem(
            id: id,
            title: title,
            description: description,
            publishedDate: date,
            url: url,
            fullUrl: fullUrl,
            titleImageUrl: titleImageUrl,
            categoryType: categoryType
        )
    }
}

extension NewsPage {
    static func decode(from data: Data) throws -> NewsPage {
        let dto = try JSONDecoder().decode(NewsPageDTO.self, from: data)
        let items = dto.news.compactMap { itemDTO -> NewsItem? in
            try? itemDTO.makeNewsItem()
        }
        return NewsPage(news: items, totalCount: dto.totalCount)
    }
}

enum NewsDateFormatter {
    private static let parser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()
    
    static func parse(_ string: String) -> Date? {
        parser.date(from: string)
    }
    
    static let display: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.setLocalizedDateFormatFromTemplate("d MMMM")
        return formatter
    }()
}

enum NewsAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidDate(String)
    case httpStatus(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Некорректный адрес запроса."
        case .invalidResponse:
            return "Не удалось обработать ответ от сервера."
        case .invalidDate(let value):
            return "Некорректная дата новости: \(value)."
        case .httpStatus(let code):
            return "Ошибка сервера (\(code))."
        }
    }
}
