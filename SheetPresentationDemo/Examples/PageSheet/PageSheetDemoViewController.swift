import UIKit

final class PageSheetDemoViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .plain)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
    }

    private func setupUI() {
        let grabberPad = sheetDemoGrabberLayoutPadding
        let sheetNav = SheetDemoSheetNavigationView(title: "Page Sheet", onClose: { [weak self] in
            self?.dismiss(animated: true)
        })

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.dataSource = self
        tableView.delegate = self

        view.addSubview(sheetNav)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            sheetNav.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: grabberPad),
            sheetNav.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheetNav.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: sheetNav.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    deinit {
        print("[SheetDemo] PageSheetDemoViewController deinit")
    }
}

extension PageSheetDemoViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 40 }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = "Page item \(indexPath.row)"
        cell.selectionStyle = .none
        return cell
    }
}
