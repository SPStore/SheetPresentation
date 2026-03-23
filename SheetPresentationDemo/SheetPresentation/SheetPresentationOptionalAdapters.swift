//
//  SheetPresentationOptionalAdapters.swift
//  SheetPresentationDemo
//
//  不常用扩展能力：自定义非交互转场等（主文件仅保留核心展示逻辑）。
//

import UIKit

// MARK: - 非交互转场

/// 非交互式 present / dismiss 的自定义转场
@objc public protocol SheetPresentationControllerTransitionAnimating: AnyObject {

    /// 返回 `nil` 使用内置 present 动画。
    @objc optional func sheetPresentationController(
        _ sheetPresentationController: SheetPresentationController,
        animatorForNonInteractivePresentTransitionWithDuration duration: TimeInterval
    ) -> UIViewControllerAnimatedTransitioning?

    /// 返回 `nil` 使用内置非交互 dismiss；**交互式 dismiss（拖拽 / 侧滑）始终走库内实现**。
    @objc optional func sheetPresentationController(
        _ sheetPresentationController: SheetPresentationController,
        animatorForNonInteractiveDismissTransitionWithDuration duration: TimeInterval
    ) -> UIViewControllerAnimatedTransitioning?
}

// MARK: - SheetPresentationController

@MainActor
extension SheetPresentationController {

    fileprivate var transitionAnimatingDelegate: SheetPresentationControllerTransitionAnimating? {
        delegate as? SheetPresentationControllerTransitionAnimating
    }

    func resolvedNonInteractivePresentAnimator(duration: TimeInterval) -> UIViewControllerAnimatedTransitioning? {
        transitionAnimatingDelegate?.sheetPresentationController?(
            self,
            animatorForNonInteractivePresentTransitionWithDuration: duration
        )
    }

    func resolvedNonInteractiveDismissAnimator(duration: TimeInterval) -> UIViewControllerAnimatedTransitioning? {
        transitionAnimatingDelegate?.sheetPresentationController?(
            self,
            animatorForNonInteractiveDismissTransitionWithDuration: duration
        )
    }
}
