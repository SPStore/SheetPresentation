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
            initialSpringVelocity: 1.0,
            options: options,
            animations: animations,
            completion: completion
        )
    }
    
    // MARK: - UIViewControllerAnimatedTransitioning
    
    open func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return animationDuration
    }
    
    open func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if isPresenting {
            animatePresentation(using: transitionContext)
        } else {
            animateDismissal(using: transitionContext)
        }
    }
        
    private func animatePresentation(using transitionContext: UIViewControllerContextTransitioning) {
        guard
            let toVC = transitionContext.viewController(forKey: .to),
            let _ = transitionContext.viewController(forKey: .from)
        else {
            transitionContext.completeTransition(false)
            return
        }
        
        guard let presentationController = toVC.presentationController  else {
            return
        }
        
        // 获取要动画的视图
        guard let panView = presentationController.presentedView ?? toVC.view else {
            transitionContext.completeTransition(false)
            return
        }
        
        // 先记录最终要到达的位置
        let finalFrame = presentationController.frameOfPresentedViewInContainerView
        let finalYPosition = finalFrame.origin.y
        
        let containerView = transitionContext.containerView
        // 将视图移动到屏幕底部
        var initialFrame = panView.frame
        initialFrame.origin.y = containerView.bounds.height
        panView.frame = initialFrame
        
        let duration = transitionDuration(using: transitionContext)
        let options: UIView.AnimationOptions = [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]
        
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 1.0,
            initialSpringVelocity: 0,
            options: options,
            animations: {
                var finalFrame = panView.frame
                finalFrame.origin.y = finalYPosition
                panView.frame = finalFrame
            },
            completion: { finished in
                transitionContext.completeTransition(finished)
            }
        )
    }
    
    private func animateDismissal(using transitionContext: UIViewControllerContextTransitioning) {
        guard
            let fromVC = transitionContext.viewController(forKey: .from),
            let _ = transitionContext.viewController(forKey: .to)
        else {
            transitionContext.completeTransition(false)
            return
        }
        
        // 获取 presentationController
        guard let presentationController = fromVC.presentationController else {
            transitionContext.completeTransition(false)
            return
        }
        
        // 获取要动画的视图
        guard let panView = presentationController.presentedView ?? fromVC.view else {
            transitionContext.completeTransition(false)
            return
        }
        
        // 判断是否是交互式 dismiss
        if transitionContext.isInteractive {
            interactionDismiss(using: transitionContext, fromVC: fromVC, panView: panView)
        } else {
            nonInteractiveDismiss(using: transitionContext, fromVC: fromVC, panView: panView)
        }
    }
    
    /// 交互式 dismiss 动画
    private func interactionDismiss(
        using transitionContext: UIViewControllerContextTransitioning,
        fromVC: UIViewController,
        panView: UIView
    ) {
        let containerView = transitionContext.containerView
        let duration = transitionDuration(using: transitionContext)
        
        // 占位视图：交互式 dismiss 的实际位移由平移手势手动驱动，
        // 此处仅需一个最小的 UIView 动画供 UIPercentDrivenInteractiveTransition 捕获。
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
                    fromVC.view.removeFromSuperview()
                }
                transitionContext.completeTransition(!cancelled)
            }
        )
    }
    
    /// 非交互式 dismiss 动画
    private func nonInteractiveDismiss(
        using transitionContext: UIViewControllerContextTransitioning,
        fromVC: UIViewController,
        panView: UIView
    ) {
        let containerView = transitionContext.containerView
        
        performAnimation(
            animations: {
                var panViewFrame = panView.frame
                panViewFrame.origin.y = containerView.bounds.height
                panView.frame = panViewFrame
            },
            completion: { finished in
                fromVC.view.removeFromSuperview()
                transitionContext.completeTransition(finished)
            }
        )
    }
}
