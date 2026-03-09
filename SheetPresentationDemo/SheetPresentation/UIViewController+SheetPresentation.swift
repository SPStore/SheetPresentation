//
//  UIViewController+SheetPresentation.swift
//  SheetPresentationDemo
//
//  Created by 乐升平 on 2026/2/1.
//

import UIKit
import ObjectiveC

// MARK: - Namespace Wrapper

public struct CSWrapper<Base> {
    public let base: Base
    public init(_ base: Base) {
        self.base = base
    }
}

// MARK: - CSCompatible Protocol

public protocol CSCompatible {}

extension CSCompatible {
    public var cs: CSWrapper<Self> {
        CSWrapper(self)
    }
}

extension UIViewController: CSCompatible {}

// MARK: - Associated Keys

private var transitioningManagerKey: UInt8 = 0
private var sheetPresentationControllerKey: UInt8 = 0

// MARK: - UIViewController + CS Namespace

extension CSWrapper where Base: UIViewController {

    /// Sheet 转场管理器
    var transitioningManager: SheetTransitioningManager? {
        get {
            objc_getAssociatedObject(base, &transitioningManagerKey) as? SheetTransitioningManager
        }
        nonmutating set {
            objc_setAssociatedObject(base, &transitioningManagerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// Sheet 展示控制器
    var sheetPresentationController: SheetPresentationController {
        if let controller = objc_getAssociatedObject(base, &sheetPresentationControllerKey) as? SheetPresentationController {
            return controller
        }
        let controller = SheetPresentationController(presentedViewController: base, presenting: nil)
        objc_setAssociatedObject(base, &sheetPresentationControllerKey, controller, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return controller
    }

    /// 以 Sheet 方式展示视图控制器
    func presentSheetViewController(_ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
        let transitioningManager = SheetTransitioningManager()
        viewControllerToPresent.cs.transitioningManager = transitioningManager
        viewControllerToPresent.modalPresentationCapturesStatusBarAppearance = true
        viewControllerToPresent.modalPresentationStyle = .custom
        viewControllerToPresent.transitioningDelegate = transitioningManager

        base.present(viewControllerToPresent, animated: animated, completion: completion)
    }
}
