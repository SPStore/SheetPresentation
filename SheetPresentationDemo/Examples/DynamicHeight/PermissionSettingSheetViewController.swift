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

// MARK: - Cell

private final class PermissionSettingCell: UITableViewCell {
    static let reuseId = "PermissionSettingCell"

    let titleLabel = UILabel()
    private let containerView = UIView()
    private let separatorLine = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .white

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .boldSystemFont(ofSize: 15)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0

        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        separatorLine.backgroundColor = UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 0.29)

        contentView.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(separatorLine)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 15),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -15),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            separatorLine.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            separatorLine.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func applyRoundedAppearance(indexPath: IndexPath, totalInSection: Int) {
        containerView.layer.cornerRadius = 8
        containerView.layer.masksToBounds = true
        if totalInSection == 1 {
            containerView.layer.maskedCorners = [
                .layerMinXMinYCorner, .layerMaxXMinYCorner,
                .layerMinXMaxYCorner, .layerMaxXMaxYCorner
            ]
            separatorLine.isHidden = true
        } else if indexPath.row == 0 {
            containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            separatorLine.isHidden = false
        } else if indexPath.row == totalInSection - 1 {
            containerView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            separatorLine.isHidden = true
        } else {
            containerView.layer.cornerRadius = 0
            separatorLine.isHidden = false
        }
    }
}
