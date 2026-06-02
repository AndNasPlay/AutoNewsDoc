import Combine
import SafariServices
import UIKit

final class FeedViewController: UIViewController {
    private enum UIConstant {
        static let sectionHorizontalInset: CGFloat = IPadFormFactor.isPad ? 24 : 12
        static let sectionVerticalInset: CGFloat = 12
        static let interGroupSpacing: CGFloat = 12
        static let footerHeight: CGFloat = 56
    }

    private let viewModel: FeedViewModel
    private var cancellables = Set<AnyCancellable>()
    private lazy var dataSource: UICollectionViewDiffableDataSource<Int, NewsItem> = makeDataSource()
    private var items: [NewsItem] = []
    private var imageStates: [Int: NewsCellImageState] = [:]
    private var loadingImageIDs = Set<Int>()
    private var pendingImageItems: [NewsItem] = []
    private let maxConcurrentImageLoads = 4

    private(set) lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.register(NewsCell.self, forCellWithReuseIdentifier: NewsCell.reuseIdentifier)
        collectionView.register(
            LoadingFooterView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: LoadingFooterView.reuseIdentifier
        )
        return collectionView
    }()

    private(set) lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        return control
    }()

    private(set) lazy var initialLoader: UIActivityIndicatorView = {
        let loader = UIActivityIndicatorView(style: .large)
        loader.hidesWhenStopped = true
        loader.translatesAutoresizingMaskIntoConstraints = false
        return loader
    }()

    init(viewModel: FeedViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.viewModel = FeedViewModel()
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigation()
        configureHierarchy()
        bindViewModel()
    }

    private func configureNavigation() {
        title = "Новости"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
    }

    private func configureHierarchy() {
        view.backgroundColor = .systemBackground
        view.addSubview(collectionView)
        view.addSubview(initialLoader)
        collectionView.refreshControl = refreshControl

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            initialLoader.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            initialLoader.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Int, NewsItem> {
        let dataSource = UICollectionViewDiffableDataSource<Int, NewsItem>(collectionView: collectionView) { [weak self] collectionView, indexPath, item in
            guard let self else { return nil }
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: NewsCell.reuseIdentifier,
                for: indexPath
            ) as? NewsCell else {
                return nil
            }

            let imageState = self.imageStates[item.id] ?? .hidden
            cell.configure(with: item, imageState: imageState)
            cell.onShowMore = { [weak self] in
                guard let self, let url = item.articleURL else { return }
                self.openArticle(url)
            }
            cell.onImageTap = { [weak self, weak cell] in
                guard let self,
                      let url = item.imageURL else { return }
                self.openFullScreenImage(url: url, placeholderImage: cell?.displayedImage)
            }
            return cell
        }

        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard kind == UICollectionView.elementKindSectionFooter else { return nil }
            guard let footer = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: LoadingFooterView.reuseIdentifier,
                for: indexPath
            ) as? LoadingFooterView else {
                return nil
            }

            let isLoadingMore = self?.viewModel.loadingState == .loadingMore
            footer.setLoading(isLoadingMore)
            return footer
        }
        return dataSource
    }

    private func bindViewModel() {
        viewModel.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.applyItems(items)
            }
            .store(in: &cancellables)

        viewModel.$loadingState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.applyLoadingState(state)
            }
            .store(in: &cancellables)
    }

    private func applyLoadingState(_ state: FeedLoadingState) {
        switch state {
        case .idle:
            initialLoader.stopAnimating()
            refreshControl.endRefreshing()
        case .loadingInitial:
            if items.isEmpty {
                initialLoader.startAnimating()
            }
        case .loadingMore:
            break
        case .failed(let message):
            initialLoader.stopAnimating()
            refreshControl.endRefreshing()
            showErrorAlert(message: message)
        }
    }

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ОК", style: .default))
        present(alert, animated: true)
    }

    @objc private func handleRefresh() {
        Task { await viewModel.refresh() }
    }

    private func applyItems(_ items: [NewsItem]) {
        let isInitialLoad = self.items.isEmpty && !items.isEmpty
        self.items = items
        pendingImageItems.removeAll()
        var snapshot = NSDiffableDataSourceSnapshot<Int, NewsItem>()
        snapshot.appendSections([0])
        snapshot.appendItems(items, toSection: 0)
        dataSource.apply(snapshot, animatingDifferences: !isInitialLoad) { [weak self] in
            self?.loadVisibleImages()
        }
    }

    private func loadVisibleImages() {
        let visibleItems = collectionView.indexPathsForVisibleItems
            .sorted { $0.item < $1.item }
            .compactMap { dataSource.itemIdentifier(for: $0) }
        for item in visibleItems {
            enqueueImageLoadIfNeeded(for: item)
        }
        processImageQueueIfNeeded()
    }

    private func enqueueImageLoadIfNeeded(for item: NewsItem) {
        guard item.hasImage, item.imageURL != nil else { return }
        if case .loaded = imageStates[item.id] { return }
        if loadingImageIDs.contains(item.id) { return }
        if pendingImageItems.contains(where: { $0.id == item.id }) { return }
        pendingImageItems.append(item)
    }

    private func processImageQueueIfNeeded() {
        while loadingImageIDs.count < maxConcurrentImageLoads, !pendingImageItems.isEmpty {
            startImageLoad(for: pendingImageItems.removeFirst())
        }
    }

    private func startImageLoad(for item: NewsItem) {
        guard let url = item.imageURL else { return }
        let itemID = item.id

        loadingImageIDs.insert(itemID)
        imageStates[itemID] = .loading
        updateVisibleCellImageState(for: item)

        Task.detached(priority: .utility) {
            let image = await ImageLoader.shared.image(for: url)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.loadingImageIDs.remove(itemID)
                if let image, self.isItemVisible(item) {
                    self.imageStates[itemID] = .loaded(image)
                } else if image != nil {
                    self.imageStates[itemID] = .hidden
                } else {
                    self.imageStates[itemID] = .failed
                }
                self.updateVisibleCellImageState(for: item)
                self.processImageQueueIfNeeded()
            }
        }
    }

    private func updateVisibleCellImageState(for item: NewsItem) {
        guard let indexPath = dataSource.indexPath(for: item),
              let cell = collectionView.cellForItem(at: indexPath) as? NewsCell else {
            return
        }
        let state = imageStates[item.id] ?? .hidden
        cell.setImageState(state)
    }

    private func isItemVisible(_ item: NewsItem) -> Bool {
        guard let indexPath = dataSource.indexPath(for: item) else { return false }
        return collectionView.indexPathsForVisibleItems.contains(indexPath)
    }

    private func openArticle(_ url: URL) {
        let controller = SFSafariViewController(url: url)
        present(controller, animated: true)
    }

    private func openFullScreenImage(url: URL, placeholderImage: UIImage?) {
        let viewer = FullScreenImageViewController(imageURL: url, placeholderImage: placeholderImage)
        present(viewer, animated: true)
    }

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] _, _ in
            guard self != nil else { return nil }

            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .estimated(IPadFormFactor.isPad ? 500 : 400)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = UIConstant.interGroupSpacing
            section.contentInsets = NSDirectionalEdgeInsets(
                top: UIConstant.sectionVerticalInset,
                leading: UIConstant.sectionHorizontalInset,
                bottom: UIConstant.sectionVerticalInset,
                trailing: UIConstant.sectionHorizontalInset
            )

            let footerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .absolute(UIConstant.footerHeight)
            )
            let footer = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: footerSize,
                elementKind: UICollectionView.elementKindSectionFooter,
                alignment: .bottom
            )
            section.boundarySupplementaryItems = [footer]
            return section
        }
    }
}

extension FeedViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let item = dataSource.itemIdentifier(for: indexPath) {
            enqueueImageLoadIfNeeded(for: item)
            processImageQueueIfNeeded()
        }
        Task { [weak self] in
            await self?.viewModel.loadMoreIfNeeded(currentIndex: indexPath.item)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        if case .loaded = imageStates[item.id] {
            imageStates[item.id] = .hidden
        }
        if let newsCell = cell as? NewsCell {
            newsCell.setImageState(.hidden)
        }
    }
}
