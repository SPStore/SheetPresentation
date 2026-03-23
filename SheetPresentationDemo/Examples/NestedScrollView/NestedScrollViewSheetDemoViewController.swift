import UIKit

final class NestedScrollViewSheetDemoViewController: UIViewController {

    private enum TableChrome {
        static let horizontalInset: CGFloat = 10
        static let topCornerRadius: CGFloat = 12
    }

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let layout = UICollectionViewFlowLayout()
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGray6
        setupUI()
    }

    private func setupUI() {
        let grabberPad = sheetDemoGrabberLayoutPadding
        let sheetNav = SheetDemoSheetNavigationView(title: "Nested ScrollView", onClose: { [weak self] in
            self?.dismiss(animated: true)
        })

        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 64, height: 64)
        layout.minimumLineSpacing = 10
        layout.sectionInset = .init(top: 10, left: 10, bottom: 10, right: 10);
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemGray6
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "h")
        collectionView.dataSource = self
        collectionView.delegate = self

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .secondarySystemGroupedBackground
        tableView.layer.cornerRadius = TableChrome.topCornerRadius
        tableView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        tableView.clipsToBounds = true

        view.addSubview(sheetNav)
        view.addSubview(collectionView)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            sheetNav.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: grabberPad),
            sheetNav.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheetNav.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            collectionView.topAnchor.constraint(equalTo: sheetNav.bottomAnchor, constant: 0),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 90),
            tableView.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 0),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: TableChrome.horizontalInset),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -TableChrome.horizontalInset),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    deinit {
        print("[SheetDemo] NestedScrollViewSheetDemoViewController deinit")
    }
}

extension NestedScrollViewSheetDemoViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 40 }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = "Row \(indexPath.row)"
        cell.selectionStyle = .none
        return cell
    }
}

extension NestedScrollViewSheetDemoViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { 16 }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "h", for: indexPath)
        cell.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.85)
        cell.layer.cornerRadius = 10
        return cell
    }
}
