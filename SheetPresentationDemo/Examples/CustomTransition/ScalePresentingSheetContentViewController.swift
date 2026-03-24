import UIKit

// MARK: - ScalePresentingSheetContentViewController

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

    private static var hintHasBeenShown = false
    private weak var hintView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        cs.sheetPresentationController.delegate = self
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showHint()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard isBeingDismissed else { return }
        dismissHint()
        transitionCoordinator?.animate(
            alongsideTransition: { [weak self] _ in self?.applyProgress(0) },
            completion: { [weak self] ctx in
                if !ctx.isCancelled {
                    self?.presentingViewController?.view.layer.masksToBounds = false
                }
            }
        )
    }

    // MARK: - UI

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

    // MARK: - Hint

    private func showHint() {
        guard !Self.hintHasBeenShown else { return }
        Self.hintHasBeenShown = true
        guard let containerView = presentationController?.containerView,
              let presentedView = presentationController?.presentedView else { return }

        let arrowView = UIImageView(image: UIImage(systemName: "arrow.up"))
        arrowView.tintColor = .white
        arrowView.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = "上推观察动画"
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.85)

        let stack = UIStackView(arrangedSubviews: [arrowView, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        arrowView.widthAnchor.constraint(equalToConstant: 16).isActive = true
        arrowView.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let hint = UIView()
        hint.isUserInteractionEnabled = false
        hint.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: hint.topAnchor),
            stack.bottomAnchor.constraint(equalTo: hint.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: hint.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: hint.trailingAnchor),
        ])

        // 用 frame 定位，方便在 didUpdatePresentedFrame 中每帧直接更新 origin.y
        let hintSize = hint.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let sheetY = presentedView.frame.minY
        hint.frame = CGRect(
            x: containerView.bounds.midX - hintSize.width / 2,
            y: sheetY - hintSize.height - 16,
            width: hintSize.width,
            height: hintSize.height
        )

        containerView.addSubview(hint)
        hintView = hint

        let bounce = CABasicAnimation(keyPath: "transform.translation.y")
        bounce.fromValue = 0
        bounce.toValue = -7
        bounce.duration = 0.55
        bounce.autoreverses = true
        bounce.repeatCount = .infinity
        bounce.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        hint.layer.add(bounce, forKey: "bounce")
    }

    private func updateHint(sheetMinY: CGFloat, mediumY: CGFloat) {
        guard let hint = hintView else { return }
        hint.frame.origin.y = sheetMinY - hint.frame.height - 16
        if sheetMinY < mediumY - 1 {
            dismissHint()
        }
    }

    private func dismissHint() {
        guard let hint = hintView else { return }
        hintView = nil
        hint.layer.removeAllAnimations()
        hint.removeFromSuperview()
    }

    // MARK: - Scale

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
        let mediumY = sheetPresentationController.frameOfPresentedView(for: DetentID.medium).origin.y

        updateHint(sheetMinY: frame.origin.y, mediumY: mediumY)

        let largeY = sheetPresentationController.frameOfPresentedView(for: DetentID.large).origin.y
        let range = mediumY - largeY
        guard range > 1 else { return }
        applyProgress((mediumY - frame.origin.y) / range)
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
