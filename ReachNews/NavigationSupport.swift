import SwiftUI
import UIKit

/// SwiftUI's NavigationStack owns its UIKit navigation controller internally.
/// Releasing the default delegate keeps the native edge-swipe gesture available
/// even when a destination hides the navigation bar.
struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.enableInteractivePop()
    }

    final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            enableInteractivePop()
        }

        func enableInteractivePop() {
            DispatchQueue.main.async { [weak self] in
                var current: UIViewController? = self
                while let parent = current?.parent { current = parent }
                let navigationController = (current as? UINavigationController) ?? self?.navigationController
                navigationController?.interactivePopGestureRecognizer?.isEnabled = true
                navigationController?.interactivePopGestureRecognizer?.delegate = nil
            }
        }
    }
}
