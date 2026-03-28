import UIKit
import SheetPresentation

/// 两个动态高度 Sheet：无 tableView（纯约束撑起）/ 含 tableView（contentSize + 边距）。
final class DynamicHeightDemoViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Dynamic Height"
        view.backgroundColor = .systemBackground

        let buttonNoTable = makeTealButton(
            main: "Show me\n",
            detail: "（不含tableView）",
            action: #selector(showReminderToSleepPop)
        )
        let buttonWithTable = makeTealButton(
            main: "Show me\n",
            detail: "（含tableView）",
            action: #selector(showPermissionSettingPop)
        )

        let stack = UIStackView(arrangedSubviews: [buttonNoTable, buttonWithTable])
        stack.axis = .vertical
        stack.spacing = 30
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let buttonHeight: CGFloat = 50
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.widthAnchor.constraint(equalToConstant: 200),
            buttonNoTable.heightAnchor.constraint(equalToConstant: buttonHeight),
            buttonWithTable.heightAnchor.constraint(equalToConstant: buttonHeight)
        ])
    }

    private func makeTealButton(main: String, detail: String, action: Selector) -> UIButton {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        let full = main + detail
        let attr = NSMutableAttributedString(string: full)
        if let range = full.range(of: detail) {
            let ns = NSRange(range, in: full)
            attr.addAttribute(.font, value: UIFont.systemFont(ofSize: 14), range: ns)
        }
        button.setAttributedTitle(attr, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
        button.backgroundColor = .systemTeal
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func showReminderToSleepPop() {
        let vc = ReminderToSleepSheetViewController()
        let sheet = vc.cs.sheetPresentationController
        let settings = SheetDemoSettingsStore.shared
        applySharedSheetSettings(sheet, settings: settings)

        let layoutWidth = UIScreen.main.bounds.width
        weak var weakVC = vc
        sheet.detents = [
            .custom(identifier: ReminderToSleepSheetViewController.detentId) { ctx in
                guard let c = weakVC else { return min(280, ctx.maximumDetentValue) }
                let h = ReminderToSleepSheetViewController.preferredContentHeight(width: layoutWidth, for: c)
                return min(max(h, 200), ctx.maximumDetentValue)
            }
        ]
        sheet.selectedDetentIdentifier = ReminderToSleepSheetViewController.detentId

        vc.isModalInPresentation = settings.isModalInPresentation
        cs.presentSheetViewController(vc, animated: true)
    }

    @objc private func showPermissionSettingPop() {
        let vc = PermissionSettingSheetViewController()
        let sheet = vc.cs.sheetPresentationController
        let settings = SheetDemoSettingsStore.shared
        applySharedSheetSettings(sheet, settings: settings)

        sheet.allowsTapBackgroundToDismiss = true
        sheet.dimmingBackgroundAlpha = 0.4
        sheet.preferredCornerRadius = 15
        sheet.prefersGrabberVisible = true

        weak var weakVC = vc
        sheet.detents = [
            .custom(identifier: PermissionSettingSheetViewController.detentId) { ctx in
                guard let c = weakVC else { return min(400, ctx.maximumDetentValue) }
                let h = PermissionSettingSheetViewController.preferredSheetHeight(for: c)
                return min(max(h, 200), ctx.maximumDetentValue)
            }
        ]
        sheet.selectedDetentIdentifier = PermissionSettingSheetViewController.detentId

        vc.isModalInPresentation = settings.isModalInPresentation
        cs.presentSheetViewController(vc, animated: true)
    }

    private func applySharedSheetSettings(_ sheet: SheetPresentationController, settings: SheetDemoSettingsStore) {
        sheet.allowsScrollViewToDriveSheet = settings.allowsScrollViewToDriveSheet
        sheet.allowsPanGestureToDriveSheet = settings.allowsPanGestureToDriveSheet
        sheet.prefersSheetPanOverpullWithDamping = settings.prefersSheetPanOverpullWithDamping
        sheet.prefersShadowVisible = settings.prefersShadowVisible
        if #available(iOS 26, *) {
            sheet.prefersFloatingStyle = settings.prefersFloatingStyle
        }
    }
}
