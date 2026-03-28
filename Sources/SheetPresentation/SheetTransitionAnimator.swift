//
//  SheetTransitionAnimator.swift
//  SheetPresentationDemo
//
//  Created by 乐升平 on 2026/1/31.
//

import UIKit

open class SheetTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
        
    /// 是否是present动画
    public let isPresenting: Bool
    /// 转场时长（present / dismiss 统一使用）
    public let animationDuration: TimeInterval
            
    public init(isPresenting: Bool, animationDuration: TimeInterval = 0.3) {
        self.isPresenting = isPresenting
        self.animationDuration = animationDuration
        super.init()
    }
    
    public func performAnimation(
        animations: @escaping () -> Void,
        completion: @escaping (Bool) -> Void
    ) {
        let duration = transitionDuration(using: nil)
        let options: UIView.AnimationOptions = [.curveEaseIn, .beginFromCurrentState]
        
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 1.0,
            initialSpringVelocity: 0.0,
            options: options,
            animations: animations,
            completion: completion
        )
    }
    
    // MARK: - UIViewControllerAnimatedTransitioning
    
    open func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        animationDuration
    }
    
    @MainActor
    open func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if isPresenting {
            animatePresentation(using: transitionContext)
        } else {
            animateDismissal(using: transitionContext)
        }
    }
        
    @MainActor
    private func animatePresentation(using transitionContext: UIViewControllerContextTransitioning) {
        guard
            let toVC = transitionContext.viewController(forKey: .to),
            let _ = transitionContext.viewController(forKey: .from)
        else {
            transitionContext.completeTransition(false)
            return
        }
        
        guard let sheetController = toVC.presentationController as? SheetPresentationController else {
            transitionContext.completeTransition(false)
            return
        }
        
        // 获取要动画的视图
        guard sheetController.presentedView != nil else {
            transitionContext.completeTransition(false)
            return
        }
        
        // 先记录最终要到达的位置
        let finalYPosition = sheetController.frameOfPresentedViewInContainerView.origin.y
        
        // 将视图移动到屏幕底部作为起始位置
        let containerView = transitionContext.containerView
        sheetController.updatePresentedViewFrame(forYPosition: containerView.bounds.height)
        
        let duration = transitionDuration(using: transitionContext)
        let options: UIView.AnimationOptions = [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]
        
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 1.0,
            initialSpringVelocity: 0,
            options: options,
            animations: {
                sheetController.updatePresentedViewFrame(forYPosition: finalYPosition)
            },
            completion: { finished in
                transitionContext.completeTransition(finished)
            }
        )
    }
    
    @MainActor
    private func animateDismissal(using transitionContext: UIViewControllerContextTransitioning) {
        guard
            let fromVC = transitionContext.viewController(forKey: .from),
            let _ = transitionContext.viewController(forKey: .to)
        else {
            transitionContext.completeTransition(false)
            return
        }
        
        guard let sheetController = fromVC.presentationController as? SheetPresentationController else {
            transitionContext.completeTransition(false)
            return
        }
        
        // 判断是否是交互式 dismiss
        if transitionContext.isInteractive {
            interactionDismiss(using: transitionContext, sheetController: sheetController)
        } else {
            nonInteractiveDismiss(
                using: transitionContext,
                sheetController: sheetController
            )
        }
    }
    
    /// 交互式 dismiss 动画。
    /// - 侧滑（screen edge）：由 UIPercentDrivenInteractiveTransition 全程驱动，真正动画 sheet + dimming。
    /// - 拖拽越过最小 detent：帧由 SheetPresentationController 手动更新，此处仅用占位动画供 PDRIT 捕获。
    private func interactionDismiss(
        using transitionContext: UIViewControllerContextTransitioning,
        sheetController: SheetPresentationController
    ) {
        let containerView = transitionContext.containerView
        let duration = transitionDuration(using: transitionContext)

        if sheetController.isScreenEdgeInteractiveDismiss {
            // 侧滑模式：真实动画 sheet frame + dimming，完全由 UIPercentDrivenInteractiveTransition 驱动。
            let dismissY = containerView.bounds.height
            let anchorLogicalTopY = sheetController.presentedView?.frame.origin.y ?? 0
            UIView.animate(
                withDuration: duration,
                delay: 0,
                options: [.curveLinear, .allowUserInteraction, .beginFromCurrentState],
                animations: {
                    sheetController.updatePresentedViewFrame(forYPosition: dismissY)
                },
                completion: { _ in
                    let cancelled = transitionContext.transitionWasCancelled
                    if cancelled {
                        // 防止动画取消后，animations block只是更新了展示层，model层不更新，结束时再更新一次。
                        sheetController.updatePresentedViewFrame(forYPosition: anchorLogicalTopY)
                    } else {
                        sheetController.presentedViewController.view.removeFromSuperview()
                    }
                    transitionContext.completeTransition(!cancelled)
                }
            )
        } else {
            // 拖拽模式：占位视图动画，sheet 帧由控制器手动驱动。
            let animationDriver = UIView()
            containerView.addSubview(animationDriver)
            UIView.animate(
                withDuration: duration,
                delay: 0,
                options: [.curveLinear, .allowUserInteraction, .beginFromCurrentState],
                animations: {
                    animationDriver.alpha = 0
                },
                completion: { _ in
                    animationDriver.removeFromSuperview()
                    let cancelled = transitionContext.transitionWasCancelled
                    if !cancelled {
                        sheetController.presentedViewController.view.removeFromSuperview()
                    }
                    transitionContext.completeTransition(!cancelled)
                }
            )
        }
    }
    
    /// 非交互式 dismiss 动画
    @MainActor
    private func nonInteractiveDismiss(
        using transitionContext: UIViewControllerContextTransitioning,
        sheetController: SheetPresentationController
    ) {
        let containerView = transitionContext.containerView
        
        performAnimation(
            animations: {
                let bottomY = containerView.bounds.height
                sheetController.updatePresentedViewFrame(forYPosition: bottomY)
            },
            completion: { finished in
                sheetController.presentedViewController.view.removeFromSuperview()
                transitionContext.completeTransition(finished)
            }
        )
    }
}
