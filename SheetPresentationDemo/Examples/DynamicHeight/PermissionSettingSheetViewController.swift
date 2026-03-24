import UIKit

/// 含 `UITableView` 的 Sheet；高度为 `tableView.contentSize` + 顶部留白 + 底部 safe area。
final class PermissionSettingSheetViewController: UIViewController {

    static let detentId = SheetPresentationController.Detent.Identifier("dynamicHeight.permission")

    private let tableView = UITableView(frame: .zero, style: .plain)

    private let dataArray: [[String]] = [
        ["粉丝可见 • 已开启私密账号粉丝可见", "朋友可见", "私密 • 仅自己可见私密", "更多选择"],
        ["高级设置"]
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.alwaysBounceVertical = false
        tableView.tableFooterView = UIView()
        tableView.register(PermissionSettingCell.self, forCellReuseIdentifier: PermissionSettingCell.reuseId)

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor, constant: 30),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    static func preferredSheetHeight(for viewController: PermissionSettingSheetViewController) -> CGFloat {
        viewController.loadViewIfNeeded()
        let w = viewController.view.bounds.width > 1
            ? viewController.view.bounds.width
            : UIScreen.main.bounds.width
        let saved = viewController.view.bounds
        viewController.view.bounds = CGRect(x: 0, y: 0, width: w, height: 2000)
        viewController.tableView.reloadData()
        viewController.tableView.layoutIfNeeded()
        let contentH = viewController.tableView.contentSize.height
        viewController.view.bounds = saved
        let bottom = viewController.view.window?.safeAreaInsets.bottom
            ?? (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.bottom
            ?? 34
        return contentH + 30 + bottom
    }

    deinit {
        print("[SheetDemo] PermissionSettingSheetViewController deinit")
    }
}

extension PermissionSettingSheetViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { dataArray.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        dataArray[section].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PermissionSettingCell.reuseId, for: indexPath) as! PermissionSettingCell
        let sub = dataArray[indexPath.section]
        cell.titleLabel.text = sub[indexPath.row]
        cell.applyRoundedAppearance(indexPath: indexPath, totalInSection: sub.count)
        cell.selectionStyle = .none
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 55 }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        section == 1 ? UIView() : nil
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 1 ? 15 : 0
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

