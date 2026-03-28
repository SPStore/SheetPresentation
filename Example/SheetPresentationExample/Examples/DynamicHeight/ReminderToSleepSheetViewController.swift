import UIKit
import SheetPresentation

/// 子视图 Auto Layout 自上而下撑开高度（无 tableView），供 Sheet 单档 custom detent 用 `systemLayoutSizeFitting` 取值。
final class ReminderToSleepSheetViewController: UIViewController {

    private let titleLabel = UILabel()
    private let detailTitleLabel = UILabel()
    private let slider = UISlider()
    private let cancelButton = UIButton(type: .custom)
    private let reminderButton = UIButton(type: .custom)

    static let detentId = SheetPresentationController.Detent.Identifier("dynamicHeight.reminder")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "很晚了，睡个好觉"
        titleLabel.textAlignment = .center
        titleLabel.textColor = .label
        titleLabel.font = .boldSystemFont(ofSize: 16)

        detailTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        detailTitleLabel.text = "设置睡觉提醒，开启健康生活"
        detailTitleLabel.textAlignment = .center
        detailTitleLabel.textColor = .secondaryLabel
        detailTitleLabel.font = .systemFont(ofSize: 12)

        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.value = 0.3
        slider.tintColor = .systemTeal

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("取消", for: .normal)
        cancelButton.setTitleColor(.label, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 14)
        cancelButton.layer.borderWidth = 0.5
        cancelButton.layer.borderColor = UIColor.lightGray.cgColor
        cancelButton.layer.cornerRadius = 4
        cancelButton.layer.masksToBounds = true
        cancelButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)

        reminderButton.translatesAutoresizingMaskIntoConstraints = false
        reminderButton.setTitle("提醒我睡觉", for: .normal)
        reminderButton.setTitleColor(.white, for: .normal)
        reminderButton.titleLabel?.font = .systemFont(ofSize: 14)
        reminderButton.backgroundColor = .systemRed
        reminderButton.layer.cornerRadius = 4
        reminderButton.layer.masksToBounds = true
        reminderButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)

        view.addSubview(titleLabel)
        view.addSubview(detailTitleLabel)
        view.addSubview(slider)
        view.addSubview(cancelButton)
        view.addSubview(reminderButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 30),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            detailTitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            detailTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            detailTitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            slider.topAnchor.constraint(equalTo: detailTitleLabel.bottomAnchor, constant: 25),
            slider.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            slider.widthAnchor.constraint(equalToConstant: 260),

            cancelButton.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 25),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cancelButton.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -5),
            cancelButton.heightAnchor.constraint(equalToConstant: 40),

            reminderButton.topAnchor.constraint(equalTo: cancelButton.topAnchor),
            reminderButton.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 5),
            reminderButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            reminderButton.heightAnchor.constraint(equalTo: cancelButton.heightAnchor),
            reminderButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -34)
        ])
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }

    /// 在给定宽度下，用自动布局计算内容总高度。
    static func preferredContentHeight(width: CGFloat, for viewController: ReminderToSleepSheetViewController) -> CGFloat {
        viewController.loadViewIfNeeded()
        let v = viewController.view!
        v.setNeedsLayout()
        v.layoutIfNeeded()
        let h = v.systemLayoutSizeFitting(
            CGSize(width: width, height: 0),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        return h
    }

    deinit {
        print("[SheetDemo] ReminderToSleepSheetViewController deinit")
    }
}
