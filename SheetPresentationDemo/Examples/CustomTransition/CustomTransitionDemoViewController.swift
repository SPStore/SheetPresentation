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
    func animatorForPresentTransition(
        _ sheetPresentationController: SheetPresentationController
    ) -> UIViewControllerAnimatedTransitioning? {
        FadeScaleAnimator(isPresenting: true)
    }

    func animatorForDismissTransition(
        _ sheetPresentationController: SheetPresentationController
    ) -> UIViewControllerAnimatedTransitioning? {
        FadeScaleAnimator(isPresenting: false)
    }
}

