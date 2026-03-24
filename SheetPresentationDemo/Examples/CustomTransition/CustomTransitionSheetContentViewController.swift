import UIKit

// MARK: - Sheet Content VC

final class CustomTransitionSheetContentViewController: UIViewController {

    private let card = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap))
        tap.delegate = self
        view.addGestureRecognizer(tap)
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard animated else { return }
        card.alpha = 0
        card.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        transitionCoordinator?.animate(alongsideTransition: { _ in
            self.card.alpha = 1
            self.card.transform = .identity
        })
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard animated else { return }
        transitionCoordinator?.animate(alongsideTransition: { _ in
            self.card.alpha = 0
            self.card.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        }, completion: { _ in
            self.card.alpha = 1
            self.card.transform = .identity
        })
    }

    private func setupUI() {
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

final class FadeScaleAnimator: NSObject, UIViewControllerAnimatedTransitioning {

    private let isPresenting: Bool

    init(isPresenting: Bool) {
        self.isPresenting = isPresenting
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.2
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

        let duration = transitionDuration(using: ctx)

        let finalY = sheetController.frameOfPresentedViewInContainerView.origin.y
        sheetController.updatePresentedViewFrame(forYPosition: finalY)
        presentedView.alpha = 0

        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 1.2,
            options: [.allowUserInteraction],
            animations: {
                presentedView.alpha = 1
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

        let duration = transitionDuration(using: ctx)

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.curveEaseIn, .beginFromCurrentState],
            animations: {
                presentedView.alpha = 0
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
