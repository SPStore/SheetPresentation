import UIKit
import SheetPresentation

final class CommentsSheetDemoViewController: UIViewController {
    private let navBar = UIView()
    private let titleLabel = UILabel()
    private let expandDetentButton = UIButton(type: .custom)
    private let closeButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let inputContainer = UIView()
    var onRequestExpandDetents: ((SheetPresentationController) -> Void)?
    var onRequestRestoreDetents: ((SheetPresentationController) -> Void)?
    var onRequestDismissed: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 22/255, green: 22/255, blue: 22/255, alpha: 1)
        setupUI()
    }

    private func setupUI() {
        let grabberPad = sheetDemoGrabberLayoutPadding
        navBar.translatesAutoresizingMaskIntoConstraints = false
        navBar.backgroundColor = UIColor(red: 22/255, green: 22/255, blue: 22/255, alpha: 1)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "30条评论"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)

        expandDetentButton.translatesAutoresizingMaskIntoConstraints = false
        expandDetentButton.addTarget(self, action: #selector(toggleCommentsDetentHeight), for: .touchUpInside)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(named: "i_close"), for: .normal)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(closeAction), for: .touchUpInside)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = navBar.backgroundColor
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.dataSource = self
        tableView.delegate = self

        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.backgroundColor = .black
        let fakeInput = UILabel()
        fakeInput.translatesAutoresizingMaskIntoConstraints = false
        fakeInput.text = "说点什么..."
        fakeInput.textColor = UIColor(white: 0.8, alpha: 1)
        fakeInput.font = .systemFont(ofSize: 15)
        inputContainer.addSubview(fakeInput)

        view.addSubview(navBar)
        navBar.addSubview(titleLabel)
        navBar.addSubview(expandDetentButton)
        navBar.addSubview(closeButton)
        view.addSubview(tableView)
        view.addSubview(inputContainer)

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: grabberPad),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBar.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.centerXAnchor.constraint(equalTo: navBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),
            expandDetentButton.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),
            expandDetentButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            expandDetentButton.widthAnchor.constraint(equalToConstant: 30),
            expandDetentButton.heightAnchor.constraint(equalToConstant: 30),
            closeButton.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: navBar.trailingAnchor, constant: -10),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),

            inputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            fakeInput.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 16),
            fakeInput.topAnchor.constraint(equalTo: inputContainer.topAnchor, constant: 10),
            fakeInput.bottomAnchor.constraint(equalTo: inputContainer.safeAreaLayoutGuide.bottomAnchor, constant: -10),

            tableView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputContainer.topAnchor)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        syncExpandDetentButton(with: cs.sheetPresentationController)
    }

    func syncExpandDetentButton(with sheet: SheetPresentationController) {
        let isLarge = sheet.selectedDetentIdentifier == SheetPresentationController.Detent.Identifier.large
        let symbolName = isLarge ? "chevron.down" : "chevron.up"
        let sym = UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        if let img = UIImage(systemName: symbolName, withConfiguration: sym)?
            .withTintColor(.white, renderingMode: .alwaysOriginal) {
            expandDetentButton.setImage(img, for: .normal)
            expandDetentButton.setTitle(nil, for: .normal)
        } else {
            expandDetentButton.setImage(nil, for: .normal)
            expandDetentButton.setTitle(isLarge ? "收" : "大", for: .normal)
            expandDetentButton.setTitleColor(.white, for: .normal)
            expandDetentButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .regular)
        }
        expandDetentButton.accessibilityLabel = isLarge ? "收回为小档" : "展开为大档"
    }

    @objc private func toggleCommentsDetentHeight() {
        let sheet = cs.sheetPresentationController
        if sheet.selectedDetentIdentifier == SheetPresentationController.Detent.Identifier.large {
            onRequestRestoreDetents?(sheet)
        } else {
            onRequestExpandDetents?(sheet)
        }
    }

    @objc private func closeAction() {
        dismiss(animated: true) {
            self.onRequestDismissed?()
        }
    }

    deinit {
        print("[SheetDemo] CommentsSheetDemoViewController deinit")
    }
}

extension CommentsSheetDemoViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        30
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        70
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseID = "comment"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseID) ??
            UITableViewCell(style: .subtitle, reuseIdentifier: reuseID)
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        cell.textLabel?.textColor = .white
        cell.textLabel?.font = .systemFont(ofSize: 16)
        cell.detailTextLabel?.textColor = UIColor(red: 0.92, green: 0.92, blue: 0.96, alpha: 0.6)
        cell.detailTextLabel?.font = .systemFont(ofSize: 12)
        cell.textLabel?.text = indexPath.row % 2 == 0 ? "Boy" : "Girl"
        cell.detailTextLabel?.text = "\(Int.random(in: 1...59))分钟前 • \(indexPath.row % 2 == 0 ? "上海" : "北京")"
        cell.imageView?.image = UIImage(named: indexPath.row % 2 == 0 ? "icon_boy" : "icon_girl")
        let arrow = UIImageView(image: UIImage(named: "arrow_right"))
        cell.accessoryView = arrow
        return cell
    }
}
