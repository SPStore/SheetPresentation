import UIKit

// MARK: - ScalePresentingSheetContentViewController

/// 演示「present 时缩放 presenting view」效果：
/// 当 sheet 处于第 1 档（最大）时，presentingViewController.view 按比例缩小；
/// 拖拽到第 2 档恢复原大小；第 2、3 档之间切换不触发缩放。
/// 通过 `SheetPresentationControllerDelegate.sheetPresentationController(_:didUpdatePresentedFrame:)` 实时插值，
/// 效果与系统 .pageSheet 类似，拖拽过程中连续跟随。
final class ScalePresentingSheetContentViewController: UIViewController {

    enum DetentID {
        static let large  = SheetPresentationController.Detent.Identifier.large
        static let medium = SheetPresentationController.Detent.Identifier.medium
        static let small  = SheetPresentationController.Detent.Identifier("scalePres.small")
    }

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let items = Array(1...20).map { "列表项 \($0)" }

    private let minScale: CGFloat = 0.92
    private let maxCornerRadius: CGFloat = 12

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        cs.sheetPresentationController.delegate = self
        setupUI()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard isBeingDismissed else { return }
        // 随 dismiss 转场一起还原缩放，dismiss 取消时转场 coordinator 也会自动回滚
        transitionCoordinator?.animate(
            alongsideTransition: { [weak self] _ in
                self?.applyProgress(0)
            },
            completion: { [weak self] ctx in
                if !ctx.isCancelled {
                    self?.presentingViewController?.view.layer.masksToBounds = false
                }
            }
        )
    }

    // MARK: - Private

    private func setupUI() {
        let grabberPad = sheetDemoGrabberLayoutPadding
        let sheetNav = SheetDemoSheetNavigationView(title: "Scale Presenting Demo", onClose: { [weak self] in
            self?.dismiss(animated: true)
        })

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "scalePresentingCell")

        view.addSubview(sheetNav)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            sheetNav.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: grabberPad),
            sheetNav.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheetNav.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: sheetNav.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    /// progress: 0 = medium 档（identity），1 = large 档（完全缩小）
    private func applyProgress(_ progress: CGFloat) {
        let p = min(max(progress, 0), 1)
        let scale = 1.0 - p * (1.0 - minScale)
        let v = presentingViewController?.view
        v?.transform = CGAffineTransform(scaleX: scale, y: scale)
        v?.layer.cornerRadius = p * maxCornerRadius
        v?.layer.masksToBounds = p > 0
    }
}

// MARK: - SheetPresentationControllerDelegate

extension ScalePresentingSheetContentViewController: SheetPresentationControllerDelegate {

    func sheetPresentationController(
        _ sheetPresentationController: SheetPresentationController,
        didUpdatePresentedFrame frame: CGRect
    ) {
        // 每帧从 sheetPresentationController 读取参考 Y，无需手动缓存、rotation 后自动刷新
        let largeY  = sheetPresentationController.frameOfPresentedView(for: DetentID.large).origin.y
        let mediumY = sheetPresentationController.frameOfPresentedView(for: DetentID.medium).origin.y
        let range = mediumY - largeY
        guard range > 1 else { return }
        let progress = (mediumY - frame.origin.y) / range
        applyProgress(progress)
    }
}

// MARK: - UITableViewDataSource

extension ScalePresentingSheetContentViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "scalePresentingCell", for: indexPath)
        cell.textLabel?.text = items[indexPath.row]
        return cell
    }
}
