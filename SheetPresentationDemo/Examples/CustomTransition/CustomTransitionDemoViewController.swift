import UIKit

// MARK: - Entry VC（Push 进入）

final class CustomTransitionDemoViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Custom Transition"
        view.backgroundColor = .systemBackground
        setupUI()
    }

    private func setupUI() {
        let descLabel = UILabel()
        descLabel.text = "实现 SheetPresentationControllerTransitionAnimating 协议，可以为非交互式的 present / dismiss 提供完全自定义的转场动画。\n\n下方示例：present 使用淡入 + 放大，非交互式 dismiss 使用淡出 + 缩小（交互式拖拽 / 侧滑 dismiss 始终走库内实现）。"
        descLabel.numberOfLines = 0
        descLabel.font = .systemFont(ofSize: 15)
        descLabel.textColor = .secondaryLabel
        descLabel.translatesAutoresizingMaskIntoConstraints = false

        let button = UIButton(type: .system)
        button.setTitle("Present with Custom Transition", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        button.addTarget(self, action: #selector(presentSheet), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(descLabel)
        view.addSubview(button)

        NSLayoutConstraint.activate([
            descLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            descLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            descLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            button.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 32),
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    @objc private func presentSheet() {
        let contentVC = CustomTransitionSheetContentViewController()
        let controller = contentVC.cs.sheetPresentationController
        let settings = SheetDemoSettingsStore.shared
        controller.delegate = self
        controller.prefersGrabberVisible = settings.prefersGrabberVisible
        controller.preferredCornerRadius = settings.preferredCornerRadius
        controller.dimmingBackgroundAlpha = settings.dimmingBackgroundAlpha
        controller.requiresScrollingFromEdgeToDriveSheet = settings.requiresScrollingFromEdgeToDriveSheet
        controller.allowsScrollViewToDriveSheet = settings.allowsScrollViewToDriveSheet
        controller.allowsPanGestureToDriveSheet = settings.allowsPanGestureToDriveSheet
        controller.prefersScrollingExpandsWhenScrolledToEdge = settings.prefersScrollingExpandsWhenScrolledToEdge
        controller.prefersSheetPanOverpullWithDamping = settings.prefersSheetPanOverpullWithDamping
        controller.allowsTapBackgroundToDismiss = settings.allowsTapBackgroundToDismiss
        controller.isEdgePanGestureEnabled = settings.isEdgePanGestureEnabled
        controller.edgePanTriggerDistance = settings.edgePanTriggerDistance
        controller.prefersShadowVisible = settings.prefersShadowVisible
        controller.prefersFloatingStyle = settings.prefersFloatingStyle
        if #available(iOS 26, *) {
            controller.prefersGlassEffect = settings.prefersGlassEffect
        }
        contentVC.isModalInPresentation = settings.isModalInPresentation
        controller.detents = [.custom(identifier: .init("custom.height")) { _ in 400 }]
        cs.presentSheetViewController(contentVC, animated: true)
    }
}

extension CustomTransitionDemoViewController: SheetPresentationControllerDelegate {}

extension CustomTransitionDemoViewController: SheetPresentationControllerTransitionAnimating {
    func sheetPresentationController(
        _ sheetPresentationController: SheetPresentationController,
        animatorForNonInteractivePresentTransitionWithDuration duration: TimeInterval
    ) -> UIViewControllerAnimatedTransitioning? {
        FadeScaleAnimator(isPresenting: true, duration: duration)
    }

    func sheetPresentationController(
        _ sheetPresentationController: SheetPresentationController,
        animatorForNonInteractiveDismissTransitionWithDuration duration: TimeInterval
    ) -> UIViewControllerAnimatedTransitioning? {
        FadeScaleAnimator(isPresenting: false, duration: duration)
    }
}

// MARK: - Sheet Content VC

private final class CustomTransitionSheetContentViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
    }

    private func setupUI() {
        let grabberPad = sheetDemoGrabberLayoutPadding
        let sheetNav = SheetDemoSheetNavigationView(title: "Custom Transition", onClose: { [weak self] in
            self?.dismiss(animated: true)
        })

        let label = UILabel()
        label.text = "此 Sheet 使用了自定义转场动画\npresent：淡入 + 放大\ndismiss：淡出 + 缩小"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 17)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(sheetNav)
        view.addSubview(label)

        NSLayoutConstraint.activate([
            sheetNav.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: grabberPad),
            sheetNav.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheetNav.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
}

// MARK: - Custom Animator

private final class FadeScaleAnimator: NSObject, UIViewControllerAnimatedTransitioning {

    private let isPresenting: Bool
    private let duration: TimeInterval

    init(isPresenting: Bool, duration: TimeInterval) {
        self.isPresenting = isPresenting
        self.duration = duration
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        duration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if isPresenting {
            animatePresent(transitionContext)
        } else {
            animateDismiss(transitionContext)
        }
    }

    private func animatePresent(_ ctx: UIViewControllerContextTransitioning) {
        guard
            let toVC = ctx.viewController(forKey: .to),
            let sheetController = toVC.presentationController as? SheetPresentationController,
            let presentedView = sheetController.presentedView
        else {
            ctx.completeTransition(false)
            return
        }

        let finalY = sheetController.frameOfPresentedViewInContainerView.origin.y
        sheetController.updatePresentedViewFrame(forYPosition: finalY)
        presentedView.alpha = 0
        presentedView.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)

        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: {
                presentedView.alpha = 1
                presentedView.transform = .identity
            },
            completion: { finished in
                ctx.completeTransition(finished)
            }
        )
    }

    private func animateDismiss(_ ctx: UIViewControllerContextTransitioning) {
        guard
            let fromVC = ctx.viewController(forKey: .from),
            let sheetController = fromVC.presentationController as? SheetPresentationController,
            let presentedView = sheetController.presentedView
        else {
            ctx.completeTransition(false)
            return
        }

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.curveEaseIn, .beginFromCurrentState],
            animations: {
                presentedView.alpha = 0
                presentedView.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
            },
            completion: { _ in
                presentedView.alpha = 1
                presentedView.transform = .identity
                sheetController.presentedViewController.view.removeFromSuperview()
                ctx.completeTransition(!ctx.transitionWasCancelled)
            }
        )
    }
}
