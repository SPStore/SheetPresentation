//
//  SheetDemoSettingsStore.swift
//  SheetPresentationDemo
//
//  示例工程：集中保存 Sheet 演示相关开关与数值，供列表页 present 时读取。
//

import UIKit

@MainActor
final class SheetDemoSettingsStore {

    static let shared = SheetDemoSettingsStore()

    private let ud = UserDefaults.standard
    private let boolPrefix = "sheetDemo."
    private let floatPrefix = "sheetDemo.float."

    enum SettingKey: String, CaseIterable {
        case allowsTapBackgroundToDismiss
        case requiresScrollingFromEdgeToDriveSheet
        case allowsScrollViewToDriveSheet
        case allowsPanGestureToDriveSheet
        case prefersScrollingExpandsWhenScrolledToEdge
        case prefersSheetPanOverpullWithDamping
        case prefersGrabberVisible
        case isEdgePanGestureEnabled
        case prefersShadowVisible
        case prefersFloatingStyle
        case isModalInPresentation
    }

    enum FloatSettingKey: String, CaseIterable {
        case dimmingBackgroundAlpha
        case preferredCornerRadius
        case edgePanTriggerDistance

        var range: ClosedRange<CGFloat> {
            switch self {
            case .dimmingBackgroundAlpha: return 0...1
            case .preferredCornerRadius: return 0...80
            case .edgePanTriggerDistance: return 8...500
            }
        }

        var defaultValue: CGFloat {
            switch self {
            case .dimmingBackgroundAlpha: return 0.36
            case .preferredCornerRadius: return 48
            case .edgePanTriggerDistance: return 32
            }
        }
    }

    private init() {
        var defaults: [String: Any] = [:]
        for key in SettingKey.allCases {
            defaults[boolPrefix + key.rawValue] = defaultBool(for: key)
        }
        for key in FloatSettingKey.allCases {
            defaults[floatPrefix + key.rawValue] = Double(key.defaultValue)
        }
        ud.register(defaults: defaults)
    }

    private func defaultBool(for key: SettingKey) -> Bool {
        switch key {
        case .allowsTapBackgroundToDismiss: return true
        case .requiresScrollingFromEdgeToDriveSheet: return false
        case .allowsScrollViewToDriveSheet: return true
        case .allowsPanGestureToDriveSheet: return true
        case .prefersScrollingExpandsWhenScrolledToEdge: return true
        case .prefersSheetPanOverpullWithDamping: return false
        case .prefersGrabberVisible: return false
        case .isEdgePanGestureEnabled: return false
        case .prefersShadowVisible: return false
        case .prefersFloatingStyle: return false
        case .isModalInPresentation: return false
        }
    }

    private func bool(for key: SettingKey) -> Bool {
        ud.bool(forKey: boolPrefix + key.rawValue)
    }

    private func set(_ value: Bool, for key: SettingKey) {
        ud.set(value, forKey: boolPrefix + key.rawValue)
    }

    private func rawFloat(for key: FloatSettingKey) -> CGFloat {
        CGFloat(ud.double(forKey: floatPrefix + key.rawValue))
    }

    private func set(_ value: CGFloat, for key: FloatSettingKey) {
        let clamped = min(max(value, key.range.lowerBound), key.range.upperBound)
        ud.set(Double(clamped), forKey: floatPrefix + key.rawValue)
    }

    // MARK: - 与 ViewController.presentAsSheet 对齐的读接口

    var prefersGrabberVisible: Bool {
        bool(for: .prefersGrabberVisible)
    }

    var dimmingBackgroundAlpha: CGFloat {
        rawFloat(for: .dimmingBackgroundAlpha)
    }

    var preferredCornerRadius: CGFloat {
        rawFloat(for: .preferredCornerRadius)
    }

    var requiresScrollingFromEdgeToDriveSheet: Bool {
        bool(for: .requiresScrollingFromEdgeToDriveSheet)
    }

    var allowsScrollViewToDriveSheet: Bool {
        bool(for: .allowsScrollViewToDriveSheet)
    }

    var allowsPanGestureToDriveSheet: Bool {
        bool(for: .allowsPanGestureToDriveSheet)
    }

    var prefersScrollingExpandsWhenScrolledToEdge: Bool {
        bool(for: .prefersScrollingExpandsWhenScrolledToEdge)
    }

    var prefersSheetPanOverpullWithDamping: Bool {
        bool(for: .prefersSheetPanOverpullWithDamping)
    }

    var allowsTapBackgroundToDismiss: Bool {
        bool(for: .allowsTapBackgroundToDismiss)
    }

    /// 写入被 present 的 `UIViewController.isModalInPresentation`。
    var isModalInPresentation: Bool {
        bool(for: .isModalInPresentation)
    }

    var isEdgePanGestureEnabled: Bool {
        bool(for: .isEdgePanGestureEnabled)
    }

    var edgePanTriggerDistance: CGFloat {
        rawFloat(for: .edgePanTriggerDistance)
    }

    var prefersShadowVisible: Bool {
        bool(for: .prefersShadowVisible)
    }

    var prefersFloatingStyle: Bool {
        bool(for: .prefersFloatingStyle)
    }

    // MARK: - 批量配置

    /// 将当前所有设置值写入 `controller` 及被展示的 `presentedVC`。
    /// 调用后可按需覆写个别属性。
    func configure(sheetController controller: SheetPresentationController, for presentedVC: UIViewController? = nil) {
        controller.prefersGrabberVisible = prefersGrabberVisible
        controller.preferredCornerRadius = preferredCornerRadius
        controller.dimmingBackgroundAlpha = dimmingBackgroundAlpha
        controller.requiresScrollingFromEdgeToDriveSheet = requiresScrollingFromEdgeToDriveSheet
        controller.allowsScrollViewToDriveSheet = allowsScrollViewToDriveSheet
        controller.allowsPanGestureToDriveSheet = allowsPanGestureToDriveSheet
        controller.prefersScrollingExpandsWhenScrolledToEdge = prefersScrollingExpandsWhenScrolledToEdge
        controller.prefersSheetPanOverpullWithDamping = prefersSheetPanOverpullWithDamping
        controller.allowsTapBackgroundToDismiss = allowsTapBackgroundToDismiss
        controller.isEdgePanGestureEnabled = isEdgePanGestureEnabled
        controller.edgePanTriggerDistance = edgePanTriggerDistance
        controller.prefersShadowVisible = prefersShadowVisible
        if #available(iOS 26, *) {
            controller.prefersFloatingStyle = prefersFloatingStyle
        }
        presentedVC?.isModalInPresentation = isModalInPresentation
    }

    // MARK: - 设置页绑定

    func boolValue(forSetting key: SettingKey) -> Bool {
        bool(for: key)
    }

    func setBool(_ value: Bool, forSetting key: SettingKey) {
        set(value, for: key)
    }

    func floatValue(forSetting key: FloatSettingKey) -> CGFloat {
        let v = rawFloat(for: key)
        return min(max(v, key.range.lowerBound), key.range.upperBound)
    }

    func setFloat(_ value: CGFloat, forSetting key: FloatSettingKey) {
        set(value, for: key)
    }

    /// 将所有开关与数值恢复为内置默认值。
    func restoreAllToDefaults() {
        for key in SettingKey.allCases {
            set(defaultBool(for: key), for: key)
        }
        for key in FloatSettingKey.allCases {
            set(key.defaultValue, for: key)
        }
    }

    static func title(for key: SettingKey) -> String {
        switch key {
        case .allowsTapBackgroundToDismiss: return "点击背景可关闭"
        case .requiresScrollingFromEdgeToDriveSheet: return "须从边缘开始滚动才驱动 Sheet"
        case .allowsScrollViewToDriveSheet: return "允许 ScrollView 驱动 Sheet"
        case .allowsPanGestureToDriveSheet: return "允许拖动手势驱动 Sheet"
        case .prefersScrollingExpandsWhenScrolledToEdge: return "滚到边缘可展开 Sheet"
        case .prefersSheetPanOverpullWithDamping: return "最大档上拉阻尼"
        case .prefersGrabberVisible: return "显示手柄"
        case .isEdgePanGestureEnabled: return "侧滑返回手势"
        case .prefersShadowVisible: return "显示阴影"
        case .prefersFloatingStyle: return "浮动样式 (iOS 26+)"
        case .isModalInPresentation: return "模态锁定"
        }
    }

    /// 开关行的副标题；无则返回 nil。
    static func subtitle(for key: SettingKey) -> String? {
        switch key {
        case .prefersFloatingStyle:
            return "地图示例比较典型"
        case .isModalInPresentation:
            return "对应被展示控制器的 isModalInPresentation；开启后无法通过下拉等方式关闭"
        case .prefersGrabberVisible: return "顶部小横条"
        case .prefersScrollingExpandsWhenScrolledToEdge:
            return "在低档位下，向上滑动 scrollView 是否可以驱动 Sheet 展开"
        default: return nil
        }
    }

    static func title(for key: FloatSettingKey) -> String {
        switch key {
        case .dimmingBackgroundAlpha: return "背景蒙层透明度"
        case .preferredCornerRadius: return "圆角半径 (pt)"
        case .edgePanTriggerDistance: return "侧滑触发距离 (pt)"
        }
    }

    static var boolSettingsInOrder: [SettingKey] {
        SettingKey.allCases
    }

    static var floatSettingsInOrder: [FloatSettingKey] {
        FloatSettingKey.allCases
    }
}
