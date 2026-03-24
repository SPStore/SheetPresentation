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
        controller.delegate = self
        controller.detents = [.large()]
        controller.prefersGrabberVisible = false
        controller.preferredCornerRadius = 0
        controller.prefersShadowVisible = false
        controller.dimmingBackgroundAlpha = 0.4
        controller.allowsPanGestureToDriveSheet = false
        controller.allowsScrollViewToDriveSheet = false
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
        view.backgroundColor = .clear
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap))
        tap.delegate = self
        view.addGestureRecognizer(tap)
        setupUI()
    }

    private func setupUI() {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 16
        card.layer.cornerCurve = .continuous
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.12
        card.layer.shadowRadius = 20
        card.layer.shadowOffset = CGSize(width: 0, height: 6)
        card.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "自定义转场：淡入 + 放大 / 淡出 + 缩小"
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false

        let closeButton = UIButton(type: .system)
        closeButton.setTitle("关闭", for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        closeButton.setContentHuggingPriority(.required, for: .horizontal)
        closeButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(card)
        card.addSubview(label)
        card.addSubview(closeButton)

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            label.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -12),

            label.heightAnchor.constraint(greaterThanOrEqualToConstant: 28),

            closeButton.centerYAnchor.constraint(equalTo: label.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        ])
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func handleBackgroundTap() {
        dismiss(animated: true)
    }
}

extension CustomTransitionSheetContentViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // 只在触摸直接落在背景 view 上时触发，点 card 内部不响应
        touch.view == view
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
