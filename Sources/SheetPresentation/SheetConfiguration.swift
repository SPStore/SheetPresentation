//
//  SheetConfiguration.swift
//  SheetPresentationDemo
//
//  Created by 乐升平 on 2026/2/5.
//

import UIKit

/// SheetPresentationController 对外提供公开属性，内部通过此结构体聚合配置。
struct SheetConfiguration {

    var allowsTapBackgroundToDismiss: Bool = true

    var allowsScrollViewToDriveSheet: Bool = true

    var allowsPanGestureToDriveSheet: Bool = true

    var requiresScrollingFromEdgeToDriveSheet: Bool = false

    var prefersScrollingExpandsWhenScrolledToEdge: Bool = true

    var prefersSheetPanOverpullWithDamping: Bool = false

    // MARK: - 侧滑返回

    var edgePanTriggerDistance: CGFloat = 32

    var edgePanDismissVelocityThreshold: CGFloat = 500.0

    // MARK: - 动画时长

    /// 进场 / 退场转场动画时长
    var transitionAnimationDuration: TimeInterval = 0.3

    /// 交互式 dismiss 完整时长（用于计算松手后剩余动画时长）
    var interactiveDismissFullDuration: TimeInterval = 0.25

    // MARK: - Dismiss 阈值

    /// 触发 dismiss 的最小竖向速度（pt/s）
    var minVerticalVelocityToTriggerDismiss: CGFloat = 800
}
