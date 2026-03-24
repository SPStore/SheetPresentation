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

        let desc2Label = UILabel()
        desc2Label.text = "在 SheetPresentationControllerDelegate 中监听 didUpdatePresentedFrame，根据 sheet 当前 Y 与第 1、2 档参考 Y 插值，实时缩放 presentingViewController.view，效果类似系统 pageSheet。"
        desc2Label.numberOfLines = 0
        desc2Label.font = .systemFont(ofSize: 15)
        desc2Label.textColor = .secondaryLabel
        desc2Label.translatesAutoresizingMaskIntoConstraints = false

        let button2 = UIButton(type: .system)
        button2.setTitle("Present with Scale Presenting Effect", for: .normal)
        button2.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        button2.addTarget(self, action: #selector(presentScaleSheet), for: .touchUpInside)
        button2.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(descLabel)
        view.addSubview(button)
        view.addSubview(desc2Label)
        view.addSubview(button2)

        NSLayoutConstraint.activate([
            descLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            descLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            descLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            button.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 20),
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            desc2Label.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 32),
            desc2Label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            desc2Label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            button2.topAnchor.constraint(equalTo: desc2Label.bottomAnchor, constant: 20),
            button2.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    @objc private func presentScaleSheet() {
        let contentVC = ScalePresentingSheetContentViewController()
        let controller = contentVC.cs.sheetPresentationController
        controller.detents = [
            .large(),
            .medium(),
            .custom(identifier: ScalePresentingSheetContentViewController.DetentID.small) { ctx in
                max(120, ctx.maximumDetentValue * 0.25)
            },
        ]
        controller.prefersGrabberVisible = true
        cs.presentSheetViewController(contentVC, animated: true)
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

