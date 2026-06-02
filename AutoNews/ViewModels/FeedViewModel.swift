import Combine
import Foundation

nonisolated enum FeedLoadingState: Equatable, Sendable {
    case idle
    case loadingInitial
    case loadingMore
    case failed(String)
}

@MainActor
final class FeedViewModel {
    @Published private(set) var items: [NewsItem] = []
    @Published private(set) var loadingState: FeedLoadingState = .idle

    private let apiService: NewsAPIService
    private let pageSize: Int = 12

    private var currentPage = 1
    private var totalCount = 0
    private var isFetching = false
    private var pendingRefresh = false

    var isRefreshPending: Bool {
        pendingRefresh
    }

    var canLoadMore: Bool {
        items.count < totalCount
    }

    init() {
        self.apiService = LiveNewsAPIService()
        Task { await loadInitialIfNeeded() }
    }

    init(apiService: NewsAPIService) {
        self.apiService = apiService
        Task { await loadInitialIfNeeded() }
    }

    func loadInitialIfNeeded() async {
        guard items.isEmpty, !isFetching else { return }
        await loadPage(reset: true)
    }

    func refresh() async {
        if isFetching {
            pendingRefresh = true
            return
        }
        await loadPage(reset: true)
    }

    func loadMoreIfNeeded(currentIndex: Int) async {
        guard canLoadMore, !isFetching else { return }

        let thresholdIndex = items.index(items.endIndex, offsetBy: -5, limitedBy: items.startIndex) ?? items.startIndex
        guard currentIndex >= thresholdIndex else { return }

        await loadPage(reset: false)
    }

    private func loadPage(reset: Bool) async {
        guard !isFetching else {
            if reset {
                pendingRefresh = true
            }
            return
        }

        isFetching = true
        loadingState = reset ? .loadingInitial : .loadingMore

        let pageToLoad = reset ? 1 : currentPage + 1

        do {
            let page = try await apiService.fetchNews(page: pageToLoad, pageSize: pageSize)
            totalCount = page.totalCount
            currentPage = pageToLoad
            items = reset ? page.news : items + page.news
            loadingState = .idle
        } catch {
            if Self.isCancellation(error) {
                loadingState = .idle
            } else {
                loadingState = .failed(error.localizedDescription)
            }
        }

        isFetching = false
        await performPendingRefreshIfNeeded()
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }
        return (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled
    }

    private func performPendingRefreshIfNeeded() async {
        guard pendingRefresh else { return }
        pendingRefresh = false
        await loadPage(reset: true)
    }
}
