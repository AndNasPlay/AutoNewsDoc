import UIKit

enum IPadFormFactor {
    case standard
    case large
    case extraLarge

    var maxContentWidth: CGFloat {
        switch self {
        case .standard:
            return 704
        case .large:
            return 832
        case .extraLarge:
            return 960
        }
    }
    
    static var isPad: Bool = UIDevice.current.userInterfaceIdiom == .pad

    static var current: IPadFormFactor {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return .standard }

        let bounds = UIScreen.main.nativeBounds
        let scale = UIScreen.main.nativeScale
        let shortestSide = min(bounds.width, bounds.height) / scale

        switch shortestSide {
        case ..<820:
            return .standard
        case ..<1000:
            return .large
        default:
            return .extraLarge
        }
    }
}
