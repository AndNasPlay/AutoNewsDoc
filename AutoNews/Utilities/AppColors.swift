import UIKit

enum AppColors {
    static let titleTextColor: UIColor = UIColor.black
    static let mainTextColor: UIColor = UIColor(red: 0.196, green: 0.196, blue: 0.196, alpha: 1)
    static let textDateColor: UIColor = UIColor(red: 0.672, green: 0.672, blue: 0.672, alpha: 1)
    static let redMainColor: UIColor = UIColor(red: 0.624, green: 0.125, blue: 0.094, alpha: 1)
    static let categoryColor: UIColor = UIColor(red: 0.405, green: 0.405, blue: 0.405, alpha: 1)
    static let gearGrayColor: UIColor = UIColor(red: 0.672, green: 0.672, blue: 0.672, alpha: 1)
}

enum FontSize {
    static let titleLabel: CGFloat = IPadFormFactor.isPad ? 24 : 20
    static let dateLabel: CGFloat = IPadFormFactor.isPad ? 18 : 14
    static let descriptionLabel: CGFloat = IPadFormFactor.isPad ? 20 : 16
    static let showMoreButton: CGFloat = IPadFormFactor.isPad ? 20 : 16
    static let categoryLabel: CGFloat = IPadFormFactor.isPad ? 18 : 14
}

enum NewsCellImageState {
    case hidden
    case loading
    case loaded(UIImage)
    case failed
}
