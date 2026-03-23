import UIKit

final class DoubleListSheetDemoViewController: UIViewController {
    private static let listBackgroundColor = UIColor(
        red: 247.0 / 255.0,
        green: 247.0 / 255.0,
        blue: 247.0 / 255.0,
        alpha: 1.0
    )

    private let leftTable = UITableView()
    private let rightTable = UITableView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
    }

    private func setupUI() {
        let grabberPad = sheetDemoGrabberLayoutPadding
        let sheetNav = SheetDemoSheetNavigationView(title: "Double List", onClose: { [weak self] in
            self?.dismiss(animated: true)
        })

        [leftTable, rightTable].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.dataSource = self
            $0.delegate = self
            $0.backgroundColor = Self.listBackgroundColor
            view.addSubview($0)
        }

        view.addSubview(sheetNav)

        NSLayoutConstraint.activate([
            sheetNav.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: grabberPad),
            sheetNav.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheetNav.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            leftTable.topAnchor.constraint(equalTo: sheetNav.bottomAnchor),
            leftTable.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            leftTable.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.33),
            leftTable.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            rightTable.topAnchor.constraint(equalTo: sheetNav.bottomAnchor),
            rightTable.leadingAnchor.constraint(equalTo: leftTable.trailingAnchor),
            rightTable.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rightTable.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    deinit {
        print("[SheetDemo] DoubleListSheetDemoViewController deinit")
    }
}

extension DoubleListSheetDemoViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 50 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let id = "cellId"
        if let cell = tableView.dequeueReusableCell(withIdentifier: id) {
            cell.textLabel?.text = "\(indexPath.row)"
            return cell
        }
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: id)
        if tableView === leftTable {
            cell.backgroundColor = .systemGray5
        } else {
            cell.contentView.backgroundColor = .systemGray6
        }
        cell.textLabel?.text = "\(indexPath.row)"
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
