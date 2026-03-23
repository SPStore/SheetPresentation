import UIKit

final class RefreshSheetDemoViewController: UIViewController {
    private let tableView = UITableView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        let grabberPad = sheetDemoGrabberLayoutPadding
        let sheetNav = SheetDemoSheetNavigationView(
            title: "RefreshData",
            subtitle: "下拉刷新须关闭 allowsScrollViewToDriveSheet",
            onClose: { [weak self] in
                self?.dismiss(animated: true)
            }
        )

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .systemGroupedBackground
        tableView.showsVerticalScrollIndicator = false
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(sheetNav)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            sheetNav.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: grabberPad),
            sheetNav.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheetNav.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: sheetNav.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(refreshAction(_:)), for: .valueChanged)
        tableView.refreshControl = refresh
    }

    @objc private func refreshAction(_ sender: UIRefreshControl) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            self.tableView.reloadData()
            if self.tableView.refreshControl?.isRefreshing == true {
                self.tableView.refreshControl?.endRefreshing()
            }
        }
    }

    deinit {
        print("[SheetDemo] RefreshSheetDemoViewController deinit")
    }
}

extension RefreshSheetDemoViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 30 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let id = "cellId"
        if let cell = tableView.dequeueReusableCell(withIdentifier: id) {
            applyRandomTitle(to: cell)
            return cell
        }
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: id)
        cell.contentView.backgroundColor = .systemGray6
        applyRandomTitle(to: cell)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 50 }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    private func applyRandomTitle(to cell: UITableViewCell) {
        let r = Int(arc4random_uniform(3))
        if ((r + 1) % 2) == 0 {
            cell.textLabel?.text = "\(arc4random_uniform(100_001))"
        } else {
            cell.textLabel?.text = "\(arc4random_uniform(100_000_001))"
        }
    }

}
