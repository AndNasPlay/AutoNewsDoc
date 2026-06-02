import UIKit

final class NewsCell: UICollectionViewCell {
    static let reuseIdentifier = "NewsCell"

    private enum UIConstant {
        static let contentInset: CGFloat = 16
        static let stackSpacing: CGFloat = 8
        static let titleToDateSpacing: CGFloat = 4
        static let dateToDescriptionSpacing: CGFloat = 12
        static let imageCornerRadius: CGFloat = 8
        static let categoryCornerRadius: CGFloat = 16
        static let categoryBorderWidth: CGFloat = 1
        static let categoryVerticalPadding: CGFloat = 6
        static let categoryHorizontalPadding: CGFloat = 12
    }

    private enum UIContent {
        static let descriptionLines = 4
        static let showMoreTitle = "Показать полностью..."
    }

    var onShowMore: (() -> Void)?
    var onImageTap: (() -> Void)?

    private(set) lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: FontSize.titleLabel, weight: .bold)
        label.textColor = AppColors.mainTextColor
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private(set) lazy var dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: FontSize.dateLabel, weight: .regular)
        label.textColor = AppColors.textDateColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private(set) lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: FontSize.descriptionLabel, weight: .regular)
        label.textColor = AppColors.mainTextColor
        label.numberOfLines = UIContent.descriptionLines
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private(set) lazy var showMoreButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(UIContent.showMoreTitle, for: .normal)
        button.setTitleColor(AppColors.redMainColor, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: FontSize.showMoreButton, weight: .bold)
        button.contentHorizontalAlignment = .leading
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(showMoreTapped), for: .touchUpInside)
        return button
    }()

    private(set) lazy var imageContainer: UIView = {
        let view = UIView()
        view.clipsToBounds = true
        view.layer.cornerRadius = UIConstant.imageCornerRadius
        view.backgroundColor = UIColor.secondarySystemBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private(set) lazy var newsImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private(set) lazy var imageLoader: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    private(set) lazy var imagePlaceholderView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "photo"))
        imageView.tintColor = .tertiaryLabel
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private(set) lazy var categoryLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: FontSize.categoryLabel, weight: .regular)
        label.textColor = AppColors.categoryColor
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private(set) lazy var categoryContainer: UIView = {
        let view = UIView()
        view.layer.cornerRadius = UIConstant.categoryCornerRadius
        view.layer.borderWidth = UIConstant.categoryBorderWidth
        view.layer.borderColor = AppColors.categoryColor.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var imageHeightConstraint: NSLayoutConstraint?
    private var imageContainerTopConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        dateLabel.text = nil
        descriptionLabel.text = nil
        categoryLabel.text = nil
        onShowMore = nil
        onImageTap = nil
        setImageState(.hidden)
    }

    func configure(
        with item: NewsItem,
        imageState: NewsCellImageState
    ) {
        titleLabel.text = item.title
        dateLabel.text = NewsDateFormatter.display.string(from: item.publishedDate)
        descriptionLabel.text = item.description
        categoryLabel.text = item.categoryType

        setImageSectionVisible(item.hasImage)
        if item.hasImage {
            let displayState: NewsCellImageState = {
                if case .hidden = imageState { return .loading }
                return imageState
            }()
            setImageState(displayState)
        } else {
            setImageState(.hidden)
        }
    }

    func setImageState(_ state: NewsCellImageState) {
        switch state {
        case .hidden:
            newsImageView.image = nil
            imageLoader.stopAnimating()
            imagePlaceholderView.isHidden = true
        case .loading:
            newsImageView.image = nil
            imagePlaceholderView.isHidden = true
            imageLoader.startAnimating()
        case .loaded(let image):
            newsImageView.image = image
            imageLoader.stopAnimating()
            imagePlaceholderView.isHidden = true
        case .failed:
            newsImageView.image = nil
            imageLoader.stopAnimating()
            imagePlaceholderView.isHidden = false
        }
    }

    func setImageSectionVisible(_ isVisible: Bool) {
        imageContainer.isHidden = !isVisible
        imageHeightConstraint?.constant = isVisible ? (IPadFormFactor.isPad ? 300 : 220) : 0
        imageContainerTopConstraint?.constant = isVisible ? UIConstant.contentInset : 0

        if !isVisible {
            setImageState(.hidden)
        }
    }

    private func setupLayout() {
        contentView.backgroundColor = .systemBackground

        categoryContainer.addSubview(categoryLabel)
        categoryLabel.setContentHuggingPriority(.required, for: .vertical)
        categoryLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        categoryContainer.setContentHuggingPriority(.required, for: .vertical)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, dateLabel, descriptionLabel, showMoreButton])
        textStack.axis = .vertical
        textStack.spacing = UIConstant.stackSpacing
        textStack.setCustomSpacing(UIConstant.titleToDateSpacing, after: titleLabel)
        textStack.setCustomSpacing(UIConstant.dateToDescriptionSpacing, after: dateLabel)
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(textStack)
        contentView.addSubview(imageContainer)
        imageContainer.addSubview(newsImageView)
        imageContainer.addSubview(imagePlaceholderView)
        imageContainer.addSubview(imageLoader)
        imageContainer.isUserInteractionEnabled = true
        imageContainer.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(imageTapped)))
        contentView.addSubview(categoryContainer)

        let imageHeight = imageContainer.heightAnchor.constraint(equalToConstant: 0)
        imageHeightConstraint = imageHeight

        let imageTop = imageContainer.topAnchor.constraint(
            equalTo: textStack.bottomAnchor,
            constant: UIConstant.contentInset
        )
        imageContainerTopConstraint = imageTop

        NSLayoutConstraint.activate([
            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: UIConstant.contentInset),
            textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: UIConstant.contentInset),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -UIConstant.contentInset),

            imageTop,
            imageContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: UIConstant.contentInset),
            imageContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -UIConstant.contentInset),
            imageHeight,

            newsImageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            newsImageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            newsImageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            newsImageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),

            imageLoader.centerXAnchor.constraint(equalTo: imageContainer.centerXAnchor),
            imageLoader.centerYAnchor.constraint(equalTo: imageContainer.centerYAnchor),

            imagePlaceholderView.centerXAnchor.constraint(equalTo: imageContainer.centerXAnchor),
            imagePlaceholderView.centerYAnchor.constraint(equalTo: imageContainer.centerYAnchor),
            imagePlaceholderView.heightAnchor.constraint(equalToConstant: 48),

            categoryContainer.topAnchor.constraint(equalTo: imageContainer.bottomAnchor, constant: UIConstant.contentInset),
            categoryContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: UIConstant.contentInset),
            categoryContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            categoryLabel.topAnchor.constraint(equalTo: categoryContainer.topAnchor, constant: UIConstant.categoryVerticalPadding),
            categoryLabel.bottomAnchor.constraint(equalTo: categoryContainer.bottomAnchor, constant: -UIConstant.categoryVerticalPadding),
            categoryLabel.leadingAnchor.constraint(equalTo: categoryContainer.leadingAnchor, constant: UIConstant.categoryHorizontalPadding),
            categoryLabel.trailingAnchor.constraint(equalTo: categoryContainer.trailingAnchor, constant: -UIConstant.categoryHorizontalPadding),
        ])
    }

    @objc private func showMoreTapped() {
        onShowMore?()
    }

    @objc private func imageTapped() {
        onImageTap?()
    }

    var displayedImage: UIImage? {
        newsImageView.image
    }
}
