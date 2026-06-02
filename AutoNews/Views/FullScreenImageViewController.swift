import UIKit
import ImageIO

final class FullScreenImageViewController: UIViewController {

    private let imageURL: URL
    private let placeholderImage: UIImage?

    private var loadTask: Task<Void, Never>?
    private var isInteractiveDismissActive = false

    private lazy var dismissPanGesture: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handleDismissPan(_:)))
        gesture.delegate = self
        return gesture
    }()

    private(set) lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 3
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private(set) lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private(set) lazy var closeButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "xmark.circle.fill")
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: IPadFormFactor.isPad ? 40 : 28, weight: .medium)
        configuration.baseForegroundColor = .white
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        return button
    }()

    private(set) lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    init(imageURL: URL, placeholderImage: UIImage?) {
        self.imageURL = imageURL
        self.placeholderImage = placeholderImage
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        loadTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        scrollView.delegate = self

        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        view.addSubview(closeButton)
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),

            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: IPadFormFactor.isPad ? 16 : 8),
            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: IPadFormFactor.isPad ? -32 : -16),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
        scrollView.addGestureRecognizer(dismissPanGesture)

        imageView.image = placeholderImage
        loadFullImage()
    }

    private func loadFullImage() {
        if placeholderImage == nil {
            activityIndicator.startAnimating()
        }

        loadTask = Task(priority: .utility) { [weak self] in
            guard let expectedURL = await MainActor.run(resultType: URL?.self, body: { self?.imageURL }) else { return }
            let image = await ImageLoader.shared.image(for: expectedURL)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self else { return }
                guard self.imageURL == expectedURL else { return }
                self.activityIndicator.stopAnimating()
                if let image {
                    self.imageView.image = image
                }
            }
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func handleDismissPan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)

        switch gesture.state {
        case .began:
            break
        case .changed:
            if !isInteractiveDismissActive {
                guard scrollView.zoomScale <= scrollView.minimumZoomScale + 0.01,
                      scrollView.contentOffset.y <= 0,
                      translation.y > 0,
                      abs(translation.y) > abs(translation.x) else {
                    return
                }
                isInteractiveDismissActive = true
                scrollView.isScrollEnabled = false
            }

            let progress = min(max(translation.y, 0) / view.bounds.height, 1)
            scrollView.transform = CGAffineTransform(translationX: 0, y: translation.y)
            view.backgroundColor = UIColor.black.withAlphaComponent(1 - progress * 0.5)
        case .ended, .cancelled:
            defer {
                isInteractiveDismissActive = false
                scrollView.isScrollEnabled = true
            }

            guard isInteractiveDismissActive else { return }

            let shouldDismiss = translation.y > 120 || velocity.y > 600
            if shouldDismiss {
                UIView.animate(withDuration: 0.25, animations: {
                    self.scrollView.transform = CGAffineTransform(translationX: 0, y: self.view.bounds.height)
                    self.view.backgroundColor = .clear
                }, completion: { _ in
                    self.dismiss(animated: false)
                })
            } else {
                UIView.animate(
                    withDuration: 0.3,
                    delay: 0,
                    usingSpringWithDamping: 0.8,
                    initialSpringVelocity: 0,
                    animations: {
                        self.scrollView.transform = .identity
                        self.view.backgroundColor = .black
                    }
                )
            }
        default:
            break
        }
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            return
        }

        let location = gesture.location(in: imageView)
        let zoomRect = zoomRect(for: scrollView.maximumZoomScale / 2, center: location)
        scrollView.zoom(to: zoomRect, animated: true)
    }

    private func zoomRect(for scale: CGFloat, center: CGPoint) -> CGRect {
        let size = scrollView.bounds.size
        let width = size.width / scale
        let height = size.height / scale
        let originX = center.x - width / 2
        let originY = center.y - height / 2
        return CGRect(x: originX, y: originY, width: width, height: height)
    }
}

extension FullScreenImageViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }
}

extension FullScreenImageViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer === dismissPanGesture && otherGestureRecognizer === scrollView.panGestureRecognizer
    }
}


