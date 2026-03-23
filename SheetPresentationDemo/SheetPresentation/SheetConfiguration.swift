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
}
