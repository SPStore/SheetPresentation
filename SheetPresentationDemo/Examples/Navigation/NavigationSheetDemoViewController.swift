import UIKit

final class NavigationSheetDemoViewController: UIViewController {

    static func makeNavigationRoot() -> UIViewController {
        UINavigationController(rootViewController: NavigationSheetDemoViewController())
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Navigation Root"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Next",
            style: .plain,
            target: self,
            action: #selector(openNextPage)
        )
        installSheetDismissButtonOnly()

        navigationController?.cs.sheetPresentationController.selectedDetentIdentifier = .large
    }

    @objc private func openNextPage() {
        let next = UIViewController()
        next.view.backgroundColor = .systemBackground
        next.title = "Pushed In Sheet"
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "This page is pushed inside sheet navigation."
        label.textColor = .secondaryLabel
        next.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: next.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: next.view.centerYAnchor)
        ])
        navigationController?.pushViewController(next, animated: true)
    }

    private func installSheetDismissButtonOnly() {
        let grabberPad = sheetDemoGrabberLayoutPadding
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        btn.tintColor = .secondaryLabel
        btn.accessibilityLabel = "关闭"
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addAction(UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        }, for: .touchUpInside)
        view.addSubview(btn)
        NSLayoutConstraint.activate([
            btn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8 + grabberPad),
            btn.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            btn.widthAnchor.constraint(equalToConstant: 32),
            btn.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    deinit {
        print("[SheetDemo] NavigationSheetDemoViewController deinit")
    }
}
