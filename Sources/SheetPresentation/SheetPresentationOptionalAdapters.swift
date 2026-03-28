//
//  SheetPresentationOptionalAdapters.swift
//  SheetPresentationDemo
//

import UIKit

// MARK: - 非交互转场

/// 非交互式 present / dismiss 的自定义转场
@objc public protocol SheetPresentationControllerTransitionAnimating: AnyObject {

    /// 返回 `nil` 使用内置 present 动画。
    @objc optional func animatorForPresentTransition(
        _ sheetPresentationController: SheetPresentationController
    ) -> UIViewControllerAnimatedTransitioning?

    /// 返回 `nil` 使用内置非交互 dismiss；**交互式 dismiss（拖拽 / 侧滑）始终走库内实现**。
    @objc optional func animatorForDismissTransition(
        _ sheetPresentationController: SheetPresentationController
    ) -> UIViewControllerAnimatedTransitioning?
}

// MARK: - SheetPresentationController

@MainActor
extension SheetPresentationController {

    fileprivate var transitionAnimatingDelegate: SheetPresentationControllerTransitionAnimating? {
        delegate as? SheetPresentationControllerTransitionAnimating
    }

    func resolvedNonInteractivePresentAnimator() -> UIViewControllerAnimatedTransitioning? {
        transitionAnimatingDelegate?.animatorForPresentTransition?(self)
    }

    func resolvedNonInteractiveDismissAnimator() -> UIViewControllerAnimatedTransitioning? {
        transitionAnimatingDelegate?.animatorForDismissTransition?(self)
    }
}
