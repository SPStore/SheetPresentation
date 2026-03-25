import UIKit

// MARK: - Entry VC（Push 进入）

final class CustomTransitionDemoViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Custom Transition"
        view.backgroundColor = .systemGroupedBackground
        setupUI()
    }

    private func setupUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 50
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 100),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -100),
        ])

        stack.addArrangedSubview(makeButton(title: "淡入 · 淡出", action: #selector(presentFadeSheet)))
        stack.addArrangedSubview(makeButton(title: "缩放背后视图", action: #selector(presentScaleSheet)))
    }

    private func makeButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        button.backgroundColor = view.tintColor.withAlphaComponent(0.2)
        button.setTitleColor(view.tintColor, for: .normal)
        button.layer.cornerRadius = 14
        button.layer.cornerCurve = .continuous
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    // MARK: - Actions

    @objc private func presentFadeSheet() {
        let contentVC = CustomTransitionSheetContentViewController()
        let controller = contentVC.cs.sheetPresentationController
        controller.delegate = self
        
        SheetDemoSettingsStore.shared.configure(sheetController: controller)
        controller.detents = [.large()]
        controller.prefersGrabberVisible = false
        controller.allowsPanGestureToDriveSheet = false
        controller.allowsScrollViewToDriveSheet = false
        cs.presentSheetViewController(contentVC, animated: true)
    }
    
    @objc private func presentScaleSheet() {
        let contentVC = ScalePresentingSheetContentViewController()
        let controller = contentVC.cs.sheetPresentationController
        SheetDemoSettingsStore.shared.configure(sheetController: controller)
        controller.detents = [
            .large(),
            .medium(),
            .custom(identifier: ScalePresentingSheetContentViewController.DetentID.small) { ctx in
                max(120, ctx.maximumDetentValue * 0.25)
            },
        ]
        controller.dimmingBackgroundAlpha = 0.0
        controller.prefersGrabberVisible = true
        cs.presentSheetViewController(contentVC, animated: true)
    }
}

// MARK: - SheetPresentationControllerDelegate

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
