//
//  SheetTransitioningManager.swift
//  SheetPresentationDemo
//
//  Created by 乐升平 on 2026/1/31.
//

import UIKit

class SheetTransitioningManager: NSObject, UIViewControllerTransitioningDelegate {

    // MARK: - Public state

    private(set) var isInteractive: Bool = false

    // MARK: - Private

    private var interactionController: UIPercentDrivenInteractiveTransition?
    private func transitionDuration(for viewController: UIViewController) -> TimeInterval {
        return viewController.cs.sheetPresentationController.transitionAnimationDuration
    }

    // MARK: - UIViewControllerTransitioningDelegate

    func presentationController(
        forPresented presented: UIViewController,
        presenting: UIViewController?,
        source: UIViewController
    ) -> UIPresentationController? {
        return presented.cs.sheetPresentationController
    }

    func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        let duration = transitionDuration(for: presented)
        return SheetTransitionAnimator(isPresenting: true, animationDuration: duration)
    }

    func animationController(
        forDismissed dismissed: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        let duration = transitionDuration(for: dismissed)
        return SheetTransitionAnimator(isPresenting: false, animationDuration: duration)
    }

    func interactionControllerForDismissal(
        using animator: UIViewControllerAnimatedTransitioning
    ) -> UIViewControllerInteractiveTransitioning? {
        return isInteractive ? interactionController : nil
    }

    // MARK: - Interaction control

    func beginInteraction() {
        interactionController = UIPercentDrivenInteractiveTransition()
        isInteractive = true
    }

    func updateInteraction(_ percent: CGFloat) {
        interactionController?.update(percent)
    }

    var interactivePercentComplete: CGFloat {
        interactionController?.percentComplete ?? 0
    }

    func finishInteraction() {
        interactionController?.finish()
        isInteractive = false
    }

    func cancelInteraction() {
        interactionController?.cancel()
        isInteractive = false
    }
}
