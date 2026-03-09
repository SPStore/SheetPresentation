//
//  SheetConfiguration.swift
//  SheetPresentationDemo
//
//  Created by 乐升平 on 2026/2/5.
//

import UIKit

extension SheetPresentationController {
    public enum DrivingMode: Int {
        case both
        case scrollOnly
        case panOnly
        case none

        var allowsScrollDriving: Bool {
            self == .both || self == .scrollOnly
        }

        var allowsPanDriving: Bool {
            self == .both || self == .panOnly
        }
    }
}

/// SheetPresentationController 对外提供公开属性，内部通过此结构体聚合配置。
struct SheetConfiguration {

    // MARK: - 交互行为

    /// 是否允许点击背景蒙层 dismiss
    var allowsTapBackgroundToDismiss: Bool = true

    /// 手势驱动模式（scroll / pan），默认 both
    var sheetDrivingMode: SheetPresentationController.DrivingMode = .both

    /// 是否要求必须从 edge 开始滚动，scrollView 才能驱动 sheet，默认 false
    var requiresScrollingFromEdgeToDriveSheet: Bool = false

    /// 处于非最大detent时，scrollView 滑到边缘是否可带动 sheet 展开，默认 true
    var prefersScrollingExpandsWhenScrolledToEdge: Bool = true

    // MARK: - 侧滑返回

    /// 是否允许侧滑返回
    var allowScreenEdgeInteractive: Bool = false

    /// 侧滑有效触发距离
    var maxAllowedDistanceToScreenEdgeForPanInteraction: CGFloat = 50.0

    /// 侧滑结束时可触发 dismiss 的最小水平速率
    var minHorizontalVelocityToTriggerScreenEdgeDismiss: CGFloat = 500.0
}
