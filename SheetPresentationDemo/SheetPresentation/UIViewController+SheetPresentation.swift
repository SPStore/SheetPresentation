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

// MARK: - UIViewController + CS Namespace

public extension CSWrapper where Base: UIViewController {

    /// 已挂在 `base` 上的转场管理器；
    internal var attachedTransitioningManager: SheetTransitioningManager? {
        objc_getAssociatedObject(base, &transitioningManagerKey) as? SheetTransitioningManager
    }

    /// 访问时就创建
    internal var transitioningManager: SheetTransitioningManager {
        if let existing = attachedTransitioningManager {
            return existing
        }
        let manager = SheetTransitioningManager(presentedViewController: base)
        objc_setAssociatedObject(base, &transitioningManagerKey, manager, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return manager
    }

    // 通过transitioningManager懒创建sheetPresentationController
    // 不直接持有是因为在扩展里只能强引用，通过transitioningManager可以弱引用
    var sheetPresentationController: SheetPresentationController {
        transitioningManager.sheetPresentationController
    }

    /// 以 Sheet 方式展示视图控制器
    func presentSheetViewController(
        _ viewControllerToPresent: UIViewController,
        animated: Bool,
        sourceView: UIView? = nil,
        sourceRect: CGRect = .zero,
        completion: (() -> Void)? = nil
    ) {
        if UIDevice.current.userInterfaceIdiom == .pad {
            viewControllerToPresent.modalPresentationStyle = .popover
            viewControllerToPresent.popoverPresentationController?.sourceRect = sourceRect
            viewControllerToPresent.popoverPresentationController?.sourceView = sourceView ?? base.view
        } else {
            viewControllerToPresent.modalPresentationCapturesStatusBarAppearance = true
            viewControllerToPresent.modalPresentationStyle = .custom
            viewControllerToPresent.transitioningDelegate = viewControllerToPresent.cs.transitioningManager
        }
        base.present(viewControllerToPresent, animated: animated, completion: completion)
    }
}
