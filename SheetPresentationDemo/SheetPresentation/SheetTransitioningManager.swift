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

    private weak var presentedViewController: UIViewController?
    private weak var _sheetPresentationController: SheetPresentationController?

    private var interactionController: UIPercentDrivenInteractiveTransition?

    init(presentedViewController: UIViewController) {
        self.presentedViewController = presentedViewController
        super.init()
    }

    /// 与 presented VC 一一对应；实例由 UIKit 在转场期间持有，此处仅 `weak` 引用，避免 Manager ↔ SheetPC 成环。
    var sheetPresentationController: SheetPresentationController {
        if let pc = _sheetPresentationController {
            return pc
        }
        guard let presented = presentedViewController else {
            preconditionFailure("SheetTransitioningManager: presentedViewController is nil")
        }
        let pc = SheetPresentationController(presentedViewController: presented, presenting: nil)
        _sheetPresentationController = pc
        return pc
    }

    private var transitionAnimationDuration: TimeInterval {
        sheetPresentationController.transitionAnimationDuration
    }

    // MARK: - UIViewControllerTransitioningDelegate

    func presentationController(
        forPresented presented: UIViewController,
        presenting: UIViewController?,
        source: UIViewController
    ) -> UIPresentationController? {
        sheetPresentationController
    }

    /// Present 无交互式转场：delegate 返回的 animator 可直接交给 UIKit，不必再包 `SheetTransitionAnimator`。
    func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        let sheet = sheetPresentationController
        let duration = transitionAnimationDuration
        if let custom = sheet.resolvedNonInteractivePresentAnimator(duration: duration) {
            return custom
        }
        return SheetTransitionAnimator(isPresenting: true, animationDuration: duration)
    }

    func animationController(
        forDismissed dismissed: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        let sheet = sheetPresentationController
        let duration = transitionAnimationDuration
        if isInteractive {
            return SheetTransitionAnimator(isPresenting: false, animationDuration: duration)
        }
        if let custom = sheet.resolvedNonInteractiveDismissAnimator(duration: duration) {
            return custom
        }
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
    
    deinit {
        print("[SheetPresentation] SheetTransitioningManager deinit")
    }
}
