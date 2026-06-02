import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let feedViewController = FeedViewController(viewModel: FeedViewModel())
        let feedNavigationController = UINavigationController(rootViewController: feedViewController)
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = feedNavigationController
        window.tintColor = AppColors.titleTextColor
        window.makeKeyAndVisible()
        self.window = window
    }
}
