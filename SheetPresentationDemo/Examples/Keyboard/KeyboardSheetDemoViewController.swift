import UIKit

final class KeyboardSheetDemoViewController: UIViewController {
    private var bottomConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let grabberPad = sheetDemoGrabberLayoutPadding
        let sheetNav = SheetDemoSheetNavigationView(title: "Keyboard", onClose: { [weak self] in
            self?.dismiss(animated: true)
        })

        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.borderStyle = .roundedRect
        textField.placeholder = "Input something..."

        view.addSubview(sheetNav)
        view.addSubview(textField)

        bottomConstraint = textField.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        NSLayoutConstraint.activate([
            sheetNav.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: grabberPad),
            sheetNav.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheetNav.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            textField.topAnchor.constraint(equalTo: sheetNav.bottomAnchor, constant: 12),
            textField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            bottomConstraint!
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(kbShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(kbHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        print("[SheetDemo] KeyboardSheetDemoViewController deinit")
    }

    @objc private func kbShow(_ n: Notification) {
        let value = (n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
        bottomConstraint?.constant = -value + view.safeAreaInsets.bottom - 12
        UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
    }

    @objc private func kbHide() {
        bottomConstraint?.constant = -20
        UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
    }
}
