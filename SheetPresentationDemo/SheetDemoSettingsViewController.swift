//
//  SheetDemoSettingsViewController.swift
//  SheetPresentationDemo
//

import UIKit

private enum SettingsSection: Int, CaseIterable {
    case floats
    case bools

    static var sectionCount: Int { allCases.count }
}

// MARK: - 数值行：滑杆（右侧显示当前值）

private final class SheetFloatSettingCell: UITableViewCell {

    static let reuseId = "float"

    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let slider = UISlider()

    private var floatKey: SheetDemoSettingsStore.FloatSettingKey?
    private var onCommit: ((SheetDemoSettingsStore.FloatSettingKey, CGFloat) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .regular)
        valueLabel.textAlignment = .right
        valueLabel.textColor = .secondaryLabel
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)

        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        contentView.addSubview(slider)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: valueLabel.leadingAnchor, constant: -8),

            valueLabel.firstBaselineAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            valueLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),

            slider.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            slider.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            slider.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        key: SheetDemoSettingsStore.FloatSettingKey,
        value: CGFloat,
        onCommit: @escaping (SheetDemoSettingsStore.FloatSettingKey, CGFloat) -> Void
    ) {
        self.floatKey = key
        self.onCommit = onCommit
        titleLabel.text = SheetDemoSettingsStore.title(for: key)
        let r = key.range
        let span = r.upperBound - r.lowerBound
        if span > 0 {
            slider.minimumValue = 0
            slider.maximumValue = 1
            slider.value = Float((value - r.lowerBound) / span)
        } else {
            slider.value = 0
        }
        valueLabel.text = formattedText(value: value, for: key)
    }

    private func formattedText(value: CGFloat, for key: SheetDemoSettingsStore.FloatSettingKey) -> String {
        switch key {
        case .dimmingBackgroundAlpha:
            return String(format: "%.2f", Double(value))
        case .preferredCornerRadius, .edgePanTriggerDistance:
            return String(format: "%.0f", Double(value))
        }
    }

    private func valueFromSlider() -> CGFloat? {
        guard let key = floatKey else { return nil }
        let r = key.range
        let span = r.upperBound - r.lowerBound
        return CGFloat(slider.value) * span + r.lowerBound
    }

    @objc private func sliderChanged() {
        guard let key = floatKey, let v = valueFromSlider() else { return }
        valueLabel.text = formattedText(value: v, for: key)
        onCommit?(key, v)
    }
}

// MARK: - View controller

final class SheetDemoSettingsViewController: UIViewController {

    private let store = SheetDemoSettingsStore.shared

    private var isFloatingStyleAvailable: Bool {
        if #available(iOS 26, *) { return true }
        return false
    }

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.delegate = self
        tv.dataSource = self
        tv.estimatedRowHeight = 56
        return tv
    }()

    private let switchReuseId = "settingSwitch"

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sheet 设置"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "重置",
            style: .plain,
            target: self,
            action: #selector(restoreAllSettings)
        )
        view.backgroundColor = .systemGroupedBackground
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func commitFloat(_ key: SheetDemoSettingsStore.FloatSettingKey, value: CGFloat) {
        store.setFloat(value, forSetting: key)
    }

    @objc private func restoreAllSettings() {
        store.restoreAllToDefaults()
        tableView.reloadData()
    }
}

extension SheetDemoSettingsViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        SettingsSection.sectionCount
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let s = SettingsSection(rawValue: section) else { return nil }
        switch s {
        case .floats: return "数值"
        case .bools: return "开关"
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let s = SettingsSection(rawValue: section) else { return 0 }
        switch s {
        case .floats: return SheetDemoSettingsStore.floatSettingsInOrder.count
        case .bools: return SheetDemoSettingsStore.boolSettingsInOrder.count
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let s = SettingsSection(rawValue: indexPath.section) else { return 48 }
        switch s {
        case .floats: return 80
        case .bools: return UITableView.automaticDimension
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let s = SettingsSection(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        switch s {
        case .floats:
            let cell = tableView.dequeueReusableCell(withIdentifier: SheetFloatSettingCell.reuseId)
                as? SheetFloatSettingCell
                ?? SheetFloatSettingCell(style: .default, reuseIdentifier: SheetFloatSettingCell.reuseId)
            let key = SheetDemoSettingsStore.floatSettingsInOrder[indexPath.row]
            let value = store.floatValue(forSetting: key)
            cell.configure(key: key, value: value) { [weak self] k, v in
                self?.commitFloat(k, value: v)
            }
            return cell
        case .bools:
            let cell = tableView.dequeueReusableCell(withIdentifier: switchReuseId)
                ?? UITableViewCell(style: .subtitle, reuseIdentifier: switchReuseId)
            let key = SheetDemoSettingsStore.boolSettingsInOrder[indexPath.row]
            cell.textLabel?.text = SheetDemoSettingsStore.title(for: key)
            cell.textLabel?.numberOfLines = 2
            cell.detailTextLabel?.numberOfLines = 0
            cell.selectionStyle = .none

            let isUnavailable: Bool = {
                switch key {
                case .prefersFloatingStyle:
                    return !isFloatingStyleAvailable
                default:
                    return false
                }
            }()
            if isUnavailable {
                cell.detailTextLabel?.text = "需 iOS 26+ 系统"
                cell.detailTextLabel?.textColor = .secondaryLabel
            } else if let sub = SheetDemoSettingsStore.subtitle(for: key) {
                cell.detailTextLabel?.text = sub
                cell.detailTextLabel?.textColor = .secondaryLabel
            } else {
                cell.detailTextLabel?.text = nil
            }

            let sw = UISwitch()
            sw.isOn = store.boolValue(forSetting: key)
            sw.isEnabled = !isUnavailable
            sw.tag = indexPath.row
            sw.addTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
            cell.accessoryView = sw
            return cell
        }
    }

    @objc private func switchChanged(_ sender: UISwitch) {
        let keys = SheetDemoSettingsStore.boolSettingsInOrder
        guard sender.tag >= 0, sender.tag < keys.count else { return }
        let key = keys[sender.tag]
        switch key {
        case .prefersFloatingStyle:
            guard isFloatingStyleAvailable else { return }
        default:
            break
        }
        store.setBool(sender.isOn, forSetting: key)
    }
}
