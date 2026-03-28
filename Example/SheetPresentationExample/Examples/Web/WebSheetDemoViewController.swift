import UIKit
import WebKit

final class WebSheetDemoViewController: UIViewController {
    private let webView = WKWebView(frame: .zero)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let grabberPad = sheetDemoGrabberLayoutPadding
        let sheetNav = SheetDemoSheetNavigationView(title: "Web", onClose: { [weak self] in
            self?.dismiss(animated: true)
        })

        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sheetNav)
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            sheetNav.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: grabberPad),
            sheetNav.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheetNav.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            webView.topAnchor.constraint(equalTo: sheetNav.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        if let url = URL(string: "https://www.baidu.com") {
            webView.load(URLRequest(url: url))
        }
    }

    deinit {
        print("[SheetDemo] WebSheetDemoViewController deinit")
    }
}
