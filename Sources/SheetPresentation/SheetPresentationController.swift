//
//  SheetPresentationController.swift
//  SheetPresentation
//
//  Created by 乐升平 on 2026/1/30.
//

import UIKit

// MARK: - SheetPresentationControllerDelegate

@MainActor
@objc public protocol SheetPresentationControllerDelegate: UIAdaptivePresentationControllerDelegate {
    @objc optional func sheetPresentationControllerDidChangeSelectedDetentIdentifier(
        _ sheetPresentationController: SheetPresentationController
    )

    @objc optional func sheetPresentationController(
        _ sheetPresentationController: SheetPresentationController,
        didUpdatePresentedFrame frame: CGRect
    )
}

// MARK: - SheetPresentationController

@MainActor
open class SheetPresentationController: UIPresentationController {

    // MARK: - Detent 配置

    open var detents: [Detent] = [.large()] {
        didSet {
            layoutInfo.detents = detents
            syncDetentYPositionsToInteraction()
        }
    }

    /// 直接设置不带动画；需要动画请用 `animateChanges(_:)`。
    open var selectedDetentIdentifier: Detent.Identifier? {
        get { _selectedDetentIdentifier }
        set { setSelectedDetent(newValue, animated: false) }
    }

    // MARK: - 行为配置

    /// 是否允许点击背景蒙层 dismiss
    open var allowsTapBackgroundToDismiss: Bool {
        get { configuration.allowsTapBackgroundToDismiss }
        set { configuration.allowsTapBackgroundToDismiss = newValue }
    }

    /// 是否允许 scrollView 驱动 sheet，默认 true
    open var allowsScrollViewToDriveSheet: Bool {
        get { configuration.allowsScrollViewToDriveSheet }
        set { configuration.allowsScrollViewToDriveSheet = newValue }
    }

    /// 是否允许 pan 手势驱动 sheet，默认 true
    open var allowsPanGestureToDriveSheet: Bool {
        get { configuration.allowsPanGestureToDriveSheet }
        set { configuration.allowsPanGestureToDriveSheet = newValue }
    }

    /// 是否要求必须从 edge 开始滚动，scrollView 才能驱动 sheet，默认 false
    open var requiresScrollingFromEdgeToDriveSheet: Bool {
        get { configuration.requiresScrollingFromEdgeToDriveSheet }
        set { configuration.requiresScrollingFromEdgeToDriveSheet = newValue }
    }

    /// 处于非最大detent时，scrollView 滑到边缘是否可带动 sheet 展开，默认 true
    open var prefersScrollingExpandsWhenScrolledToEdge: Bool {
        get { configuration.prefersScrollingExpandsWhenScrolledToEdge }
        set { configuration.prefersScrollingExpandsWhenScrolledToEdge = newValue }
    }

    /// sheetPan 到达最大 detent 后是否允许继续上拉（带阻尼回弹），默认 false
    open var prefersSheetPanOverpullWithDamping: Bool {
        get { configuration.prefersSheetPanOverpullWithDamping }
        set { configuration.prefersSheetPanOverpullWithDamping = newValue }
    }

    // MARK: - 外观配置

    /// 圆角半径
    open var preferredCornerRadius: CGFloat = 13.0 {
        didSet { dropShadowView?.cornerRadius = preferredCornerRadius }
    }

    // 是否显示阴影效果
    open var prefersShadowVisible: Bool = false {
        didSet { dropShadowView?.isShadowVisible = prefersShadowVisible }
    }

    /// 是否显示手柄（顶部的一个小横条）
    open var prefersGrabberVisible: Bool = false {
        didSet { dropShadowView?.isGrabberVisible = prefersGrabberVisible }
    }

    private var _prefersFloatingStyle: Bool = false

    /// 是否以浮动样式展示，开启后左、右、底有间距，默认false
    @available(iOS 26, *)
    open var prefersFloatingStyle: Bool {
        get { _prefersFloatingStyle }
        set {
            _prefersFloatingStyle = newValue
            layoutInfo.prefersFloatingStyle = newValue
            syncDetentYPositionsToInteraction()
            if let id = selectedDetentIdentifier, let y = layoutInfo.yPosition(for: id) {
                updatePresentedViewFrame(forYPosition: y)
            }
        }
    }
    
    /// 背景视觉效果，nil 时背景完全透明；默认 iOS 26+ 使用开启了交互动效的 UIGlassEffect，低版本使用 systemMaterial 模糊。
    open var backgroundEffect: UIVisualEffect? = nil {
        didSet {
            dropShadowView?.backgroundEffect = backgroundEffect
        }
    }

    /// 背景蒙层透明度
    open var dimmingBackgroundAlpha: CGFloat = 0.4 {
        didSet { dimmingView?.backgroundAlpha = dimmingBackgroundAlpha }
    }

    open var transitionAnimationDuration: TimeInterval {
        get { configuration.transitionAnimationDuration }
        set { configuration.transitionAnimationDuration = newValue }
    }

    // MARK: - 侧滑返回

    /// 是否开启侧滑交互
    open var isEdgePanGestureEnabled: Bool {
        get { sheetInteraction.screenEdgePanGestureRecognizer.isEnabled }
        set { sheetInteraction.screenEdgePanGestureRecognizer.isEnabled = newValue }
    }

    /// 距离屏幕边缘多少距离可触发侧滑手势
    open var edgePanTriggerDistance: CGFloat {
        get { configuration.edgePanTriggerDistance }
        set { configuration.edgePanTriggerDistance = newValue }
    }
    
    /// 动画捕获方法，比如外部设置 selectedDetentIdentifier ，可以放到该方法的闭包中则可动画切换档位
    open func animateChanges(_ changes: @escaping () -> Void) {
        animateChanges(changes, completion: nil)
    }

    /// 获取某档位的frame
    open func frameOfPresentedView(for detentIdentifier: Detent.Identifier) -> CGRect {
        guard containerView != nil else { return .zero }
        return layoutInfo.frameOfPresentedView(for: detentIdentifier)
    }

    // MARK: - Internal Properties

    private var _selectedDetentIdentifier: Detent.Identifier?

    private var layoutInfo = SheetLayoutInfo()

    private var configuration = SheetConfiguration()

    private var dimmingView: SheetDimmingView?

    private var dropShadowView: SheetDropShadowView?

    private let sheetInteraction = SheetInteraction()

    private var sheetAnimator: UIViewPropertyAnimator?

    private var isDragging = false

    private enum InteractiveDismissSource {
        case none
        case pan        // 拖拽越过最小 detent(包括scrollPan和普通pan)
        case screenEdge // 侧滑返回
    }
    private var interactiveDismissSource: InteractiveDismissSource = .none

    var isScreenEdgeInteractiveDismiss: Bool {
        interactiveDismissSource == .screenEdge
    }

    private var isAnimatingToDetent = false

    private var isUserInitiatedDismiss = false

    private var transitioningManager: SheetTransitioningManager? {
        presentedViewController.sp.attachedTransitioningManager
    }

    private var sheetDelegate: SheetPresentationControllerDelegate? {
        delegate as? SheetPresentationControllerDelegate
    }

    public override init(
        presentedViewController: UIViewController,
        presenting presentingViewController: UIViewController?
    ) {
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
    }
    
}

// MARK: - Presentation Lifecycle

@MainActor
extension SheetPresentationController {

    open override func presentationTransitionWillBegin() {
        super.presentationTransitionWillBegin()
        guard let containerView else { return }

        delegate?.presentationController?(self, willPresentWithAdaptiveStyle: .custom, transitionCoordinator: presentedViewController.transitionCoordinator)
        
        refreshLayoutInfo(using: containerView)

        if selectedDetentIdentifier == nil,
           let smallest = layoutInfo.sortedDetentEntries.last {
            setSelectedDetent(smallest.identifier, animated: false)
        }

        setupViews()
        
        dimmingView?.alpha = 0
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { [weak self] _ in
            self?.dimmingView?.alpha = 1
        })
    }

    open override func presentationTransitionDidEnd(_ completed: Bool) {
        super.presentationTransitionDidEnd(completed)
        if !completed{
            cleanupViews()
        }
    }

    open override func dismissalTransitionWillBegin() {
        super.dismissalTransitionWillBegin()

        if isUserInitiatedDismiss {
            delegate?.presentationControllerWillDismiss?(self)
        }

        if interactiveDismissSource != .pan {
            presentedViewController.transitionCoordinator?.animate(alongsideTransition: { [weak self] _ in
                self?.dimmingView?.alpha = 0
            })
        }
    }

    open override func dismissalTransitionDidEnd(_ completed: Bool) {
        let shouldNotifyDidDismiss = isUserInitiatedDismiss
        if completed {
            if shouldNotifyDidDismiss {
                delegate?.presentationControllerDidDismiss?(self)
            }
            cleanupViews()
        } else {
            interactiveDismissSource = .none
        }
        isUserInitiatedDismiss = false
        super.dismissalTransitionDidEnd(completed)
    }
}

// MARK: - Layout

@MainActor
extension SheetPresentationController {

    open override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        guard let containerView = containerView else { return }
        
        // 宽高给大点，保证动画、交互、旋转等情况下始终“覆盖无缝、不露底”
        dimmingView?.bounds = CGRect(x: 0, y: 0, width: 1206, height: 2622)
        dimmingView?.center = CGPoint(x: containerView.bounds.midX,
                                      y: containerView.bounds.midY)

        let allowFrameUpdate =
            !isDragging &&
            interactiveDismissSource == .none &&
            !isAnimatingToDetent &&
            !isNonInteractiveTransitioning
        if allowFrameUpdate {
            let targetY = frameOfPresentedViewInContainerView.origin.y
            updatePresentedViewFrame(forYPosition: targetY)
        }
    }

    open override var presentedView: UIView? {
        dropShadowView
    }

    open override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView else { return .zero }

        if layoutInfo.containerBounds != containerView.bounds
            || layoutInfo.containerSafeAreaInsets != containerView.safeAreaInsets {
            refreshLayoutInfo(using: containerView)
        }

        return layoutInfo.frameOfPresentedView(for: selectedDetentIdentifier)
    }
}

// MARK: - View Setup

@MainActor
extension SheetPresentationController {

    private func setupViews() {
        guard let containerView else { return }

        let dimming = SheetDimmingView()
        dimming.backgroundAlpha = dimmingBackgroundAlpha
        dimming.didTap = { [weak self] in
            guard let self, self.allowsTapBackgroundToDismiss else { return }
            if self.shouldDismiss {
                self.isUserInitiatedDismiss = true
                self.presentedViewController.dismiss(animated: true)
            }
        }
        containerView.addSubview(dimming)
        dimmingView = dimming

        let shadowView = SheetDropShadowView()
        shadowView.cornerRadius = preferredCornerRadius
        shadowView.isShadowVisible = prefersShadowVisible
        shadowView.isGrabberVisible = prefersGrabberVisible
        shadowView.backgroundEffect = backgroundEffect
        containerView.addSubview(shadowView)
        dropShadowView = shadowView

        let controllerView = presentedViewController.view!
        controllerView.frame = shadowView.contentView.bounds
        controllerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        shadowView.contentView.addSubview(controllerView)

        let interaction = sheetInteraction
        interaction.delegate = self
        shadowView.addInteraction(interaction)

        syncDetentYPositionsToInteraction()

        shadowView.grabberDidClickHandler = { [weak self] in
            self?.toggleNextDetent()
        }
    }

    private func cleanupViews() {
        dimmingView?.removeFromSuperview()
        dimmingView = nil
        dropShadowView?.removeInteraction(sheetInteraction)
        dropShadowView?.removeFromSuperview()
        dropShadowView = nil
    }
}

@MainActor
extension SheetPresentationController {

    private func syncDetentYPositionsToInteraction() {
        sheetInteraction.detentYPositions = layoutInfo.sortedDetentEntries.map(\.yPosition)
    }

    private func refreshLayoutInfo(using containerView: UIView) {
        layoutInfo.performBatchUpdates {
            layoutInfo.containerBounds = containerView.bounds
            layoutInfo.containerTraitCollection = containerView.traitCollection
            layoutInfo.containerSafeAreaInsets = containerView.safeAreaInsets
            layoutInfo.prefersFloatingStyle = _prefersFloatingStyle
            layoutInfo.detents = detents
        }
        syncDetentYPositionsToInteraction()
    }
}

// MARK: - Detent Management

@MainActor
extension SheetPresentationController {

    private func setSelectedDetent(_ identifier: Detent.Identifier?, animated: Bool) {
        let oldValue = _selectedDetentIdentifier
        _selectedDetentIdentifier = identifier
        if identifier != oldValue {
            sheetDelegate?.sheetPresentationControllerDidChangeSelectedDetentIdentifier?(self)
        }
        guard let identifier else { return }
        if animated {
            animateToDetent(identifier)
        } else {
            guard let y = layoutInfo.yPosition(for: identifier) else { return }
            updatePresentedViewFrame(forYPosition: y)
        }
    }

    func updatePresentedViewFrame(forYPosition yPosition: CGFloat) {
        guard let shadowView = dropShadowView else { return }
        let previousFrame = shadowView.frame

        if _prefersFloatingStyle {
            shadowView.frame = layoutInfo.floatingPresentedLayout(at: yPosition)
        } else {
            shadowView.frame = layoutInfo.frameOfPresentedView(at: yPosition)
        }
        
        guard shadowView.frame != previousFrame else { return }
        sheetDelegate?.sheetPresentationController?(self, didUpdatePresentedFrame: shadowView.frame)
    }

    private func animateToDetent(_ identifier: Detent.Identifier) {
        guard let y = layoutInfo.yPosition(for: identifier),
              dropShadowView != nil else { return }

        isAnimatingToDetent = true

        animateChanges({ [weak self] in
            guard let self else { return }
            self.updatePresentedViewFrame(forYPosition: y)
            self.dimmingView?.alpha = 1
        }, completion: { [weak self] _ in
            guard let self else { return }
            self.isAnimatingToDetent = false
            self.containerView?.setNeedsLayout()
        })
    }
    
    private func animateChanges(
        _ changes: @escaping () -> Void,
        completion: ((UIViewAnimatingPosition) -> Void)?
    ) {
        interruptRunningSheetAnimatorIfNeeded()
        let springTiming = UISpringTimingParameters(dampingRatio: 1.0)
        let animator = UIViewPropertyAnimator(duration: 0.2, timingParameters: springTiming)
        animator.addAnimations {
            changes()
        }
        animator.addCompletion { [weak self] position in
            if self?.sheetAnimator === animator {
                self?.sheetAnimator = nil
            }
            completion?(position)
        }
        sheetAnimator = animator
        animator.startAnimation()
    }

    private func toggleNextDetent() {
        guard let currentId = selectedDetentIdentifier else { return }
        let targetId: Detent.Identifier?
        if let upperEntry = layoutInfo.relativeEntry(from: currentId, offset: -1) {
            targetId = upperEntry.identifier
        } else {
            targetId = layoutInfo.sortedDetentEntries.last?.identifier
        }
        guard let targetId else { return }
        setSelectedDetent(targetId, animated: true)
    }
}

// MARK: - Drag Resolution

@MainActor
extension SheetPresentationController {

    private func resolveDragEnd(velocity: CGPoint) {
        guard let shadowView = dropShadowView else { return }

        let currentY = shadowView.frame.minY
        let isHighVelocity = abs(velocity.y) >= configuration.minVerticalVelocityToTriggerDismiss

        if isHighVelocity {
            if velocity.y < 0 {
                resolveHighVelocityDragUp(from: currentY)
            } else {
                resolveHighVelocityDragDown(from: currentY)
            }
        } else {
            snapToNearest(from: currentY)
        }
    }

    private func resolveHighVelocityDragUp(from currentY: CGFloat) {
        guard let currentId = selectedDetentIdentifier else {
            snapToNearest(from: currentY)
            return
        }
        guard let currentEntry = layoutInfo.entry(for: currentId) else {
            snapToNearest(from: currentY)
            return
        }

        guard currentY < currentEntry.yPosition else {
            setSelectedDetent(currentId, animated: true)
            return
        }

        guard let previousEntry = layoutInfo.relativeEntry(from: currentId, offset: -1) else {
            setSelectedDetent(currentId, animated: true)
            return
        }

        if currentY < previousEntry.yPosition,
           let target = layoutInfo.relativeEntry(from: currentId, offset: -2) {
            setSelectedDetent(target.identifier, animated: true)
        } else {
            setSelectedDetent(previousEntry.identifier, animated: true)
        }
    }

    private func resolveHighVelocityDragDown(from currentY: CGFloat) {
        guard let currentId = selectedDetentIdentifier else {
            snapToNearest(from: currentY)
            return
        }

        guard let currentEntry = layoutInfo.entry(for: currentId) else {
            snapToNearest(from: currentY)
            return
        }
        guard let nextEntry = layoutInfo.relativeEntry(from: currentId, offset: 1) else {
            if currentY < currentEntry.yPosition {
                setSelectedDetent(currentId, animated: true)
                return
            }
            if shouldDismiss {
                dismissSheet()
            } else {
                setSelectedDetent(currentId, animated: true)
                delegate?.presentationControllerDidAttemptToDismiss?(self)
            }
            return
        }

        // 如果已拖过 nextEntry → 再下一档或 dismiss
        if currentY > nextEntry.yPosition {
            if let target = layoutInfo.relativeEntry(from: currentId, offset: 2) {
                setSelectedDetent(target.identifier, animated: true)
            } else {
                // 过了最小 detent
                if shouldDismiss {
                    dismissSheet()
                } else {
                    setSelectedDetent(nextEntry.identifier, animated: true)
                    delegate?.presentationControllerDidAttemptToDismiss?(self)
                }
            }
        } else {
            setSelectedDetent(nextEntry.identifier, animated: true)
        }
    }

    /// 低速拖拽：吸附到最近的 detent 或 dismiss
    private func snapToNearest(from currentY: CGFloat) {
        guard let target = layoutInfo.nearestLandingTarget(to: currentY, allowsDismiss: shouldDismiss) else {
            return
        }

        switch target {
        case let .detent(id):
            setSelectedDetent(id, animated: true)
        case .dismiss:
            dismissSheet()
        }
    }

    /// 执行 dismiss（用户操作触发）
    private func dismissSheet() {
        isUserInitiatedDismiss = true
        presentedViewController.dismiss(animated: true)
    }
}

// MARK: - Interactive Dismiss

@MainActor
extension SheetPresentationController {

    // 拖拽越过 smallestDetentYPosition → beginInteractiveDismiss()
    private func beginInteractiveDismiss() {
        isUserInitiatedDismiss = true
        interactiveDismissSource = .pan
        transitioningManager?.beginInteraction()
        presentedViewController.dismiss(animated: true)
    }

    /// 完成交互式 dismiss 转场。
    /// - finish 时：finishInteraction 与 performDismissAnimation 并发运行。
    /// - cancel 时：取消交互转场并回到最近的 detent。
    private func completeInteractiveTransition(finish: Bool, velocity: CGPoint) {
        interactiveDismissSource = .none

        if finish {
            // 剩余动画时长 = (1 - percentComplete) * 完整时长
            // finishInteraction 默认以 completionSpeed=1 播完剩余段，与 performDismissAnimation 保持一致。
            let fullDuration = configuration.interactiveDismissFullDuration
            let remaining = 1.0 - (transitioningManager?.interactivePercentComplete ?? 0)
            let dismissDuration = max(TimeInterval(remaining) * fullDuration, 0.08)
            transitioningManager?.finishInteraction()
            performDismissAnimation(duration: dismissDuration)
        } else {
            transitioningManager?.cancelInteraction()

            // 按当前位置和速率决定目标 detent，而非写死到 smallestDetent。
            // 例如：从 medium 向下拖后迅速向上拉到接近 large 的位置，应吸附到 large 而非 medium。
            resolveDragEnd(velocity: velocity)
        }
    }

    private func performDismissAnimation(duration: TimeInterval) {
        guard let containerView else { return }
        let dismissY = containerView.bounds.height

        let animator = SheetTransitionAnimator(isPresenting: false, animationDuration: duration)
        animator.performAnimation(
            animations: { [weak self] in
                guard let self else { return }
                updatePresentedViewFrame(forYPosition: dismissY)
                self.dimmingView?.alpha = 0
            },
            completion: { _ in }
        )
    }
}

// MARK: - Screen Edge Interactive Dismiss

@MainActor
extension SheetPresentationController {
    
    private func shouldFinishScreenEdgeInteraction(velocity: CGPoint) -> Bool {
        let rtl = (containerView ?? presentedViewController.view).effectiveUserInterfaceLayoutDirection == .rightToLeft
        // LTR：向右为正；RTL：向左为 dismiss，等价于对 x 取反后与阈值比较（与 SheetInteraction.gestureRecognizerShouldBegin 一致）
        let dismissDirectionVelocityX = rtl ? -velocity.x : velocity.x
        let isHighVelocityTowardDismiss = dismissDirectionVelocityX >= configuration.edgePanDismissVelocityThreshold
        let progress = transitioningManager?.interactivePercentComplete ?? 0
        return isHighVelocityTowardDismiss || progress > 0.5
    }

    private func completeScreenEdgeInteractiveTransition(finish: Bool) {
        interactiveDismissSource = .none

        if finish {
            transitioningManager?.finishInteraction()
        } else {
            transitioningManager?.cancelInteraction()
        }
    }
}

// MARK: - Dimming And Animation

@MainActor
extension SheetPresentationController {

    private func updateDimmingForPosition(_ yPosition: CGFloat) {
        let progress = layoutInfo.dimmingProgress(at: yPosition)
        dimmingView?.alpha = 1 - progress
    }

    /// 手势接管前中断正在进行的 sheet 动画，并将 model 层对齐到当前可见状态。
    private func interruptRunningSheetAnimatorIfNeeded() {
        guard let animator = sheetAnimator else { return }
        // stop后，model 值（如 view.frame / view.alpha）会自动与当前可见状态（presentation）对齐。手势接管之后不会发生跳变。
        animator.stopAnimation(false)
        animator.finishAnimation(at: .current)
    }
    
    var shouldDismiss: Bool {
        if presentedViewController.isModalInPresentation { return false }
        if let adaptiveDelegate = delegate {
            return adaptiveDelegate.presentationControllerShouldDismiss?(self) ?? true
        }
        return true
    }
}

// MARK: - SheetInteractionDelegate

extension SheetPresentationController: SheetInteractionDelegate {

    func sheetInteractionDidBeginDragging(_ interaction: SheetInteraction) {
        interruptRunningSheetAnimatorIfNeeded()
        isDragging = true
    }

    func sheetInteraction(_ interaction: SheetInteraction, didChangeOffset yPosition: CGFloat) {
        guard let containerView else { return }

        let smallestDetentY = layoutInfo.smallestDetentYPosition

        // 交互式 dismiss 转场逻辑
        if shouldDismiss {
            if interactiveDismissSource == .none
                && yPosition > smallestDetentY && !presentedViewController.isBeingDismissed {
                // 首次越过最小 detent → 开始交互式 dismiss
                beginInteractiveDismiss()
            }

            if interactiveDismissSource != .none {
                let totalRange = containerView.bounds.height - smallestDetentY
                if totalRange > 0 {
                    let progress = (yPosition - smallestDetentY) / totalRange
                    let percent = min(max(progress, 0.0), 1.0)
                    transitioningManager?.updateInteraction(percent)
                }
            }
        }

        updatePresentedViewFrame(forYPosition: yPosition)
        updateDimmingForPosition(yPosition)
    }

    func sheetInteraction(_ interaction: SheetInteraction, draggingEndedWithVelocity velocity: CGPoint) {
        isDragging = false
        // 手势驱动阶段我们通过 frame 直接更新 dropShadowView；而内容子视图可能是 Auto Layout。
        // 松手到进入 animateToDetent 的交接瞬间，父视图位置通常已经是最新，但子约束可能仍停留在上一轮 layout pass，
        // 从而出现“父视图先动、子控件慢一帧”的视觉不同步
        // 这里先强制把 presentedViewController.view 的约束同步到当前帧，消除交接窗口，再进入后续吸附/dismiss 决策。
        // 现象：用力从中档位切到高档位，底部会闪一下背景，因为子控件的高度还没与父视图高度同步。
        presentedViewController.view.setNeedsLayout()
        presentedViewController.view.layoutIfNeeded()

        if interactiveDismissSource != .none {

            // ── 分支 1：交互式 dismiss 进行中（曾越过 smallestDetent），手指抬起。
            // 根据当前位置和速率决定 finish 或 cancel。
            let currentY = dropShadowView?.frame.minY ?? 0
            let containerHeight = containerView?.bounds.height ?? UIScreen.main.bounds.height
            let isBelow = currentY > layoutInfo.smallestDetentYPosition
            let isHighVelocity = velocity.y >= configuration.minVerticalVelocityToTriggerDismiss
            let dismissRange = containerHeight - layoutInfo.smallestDetentYPosition
            let isNearBottom = dismissRange > 0
                && (currentY - layoutInfo.smallestDetentYPosition) / dismissRange > 0.5

            if isBelow && (isHighVelocity || isNearBottom) {
                // ── 分支 1a：快速向下甩出，或已拖到接近屏幕底部 → 完成 dismiss，sheet 消失。
                completeInteractiveTransition(finish: true, velocity: velocity)
            } else {
                // ── 分支 1b：缓慢松手或位置靠近 smallestDetent（包含松手时已回到上方）→ 取消 dismiss，
                //    交由 resolveDragEnd 按当前位置和速率吸附到正确的 detent。
                completeInteractiveTransition(finish: false, velocity: velocity)
            }
        } else {
            // ── 分支 2：普通拖拽（未越过 smallestDetent，没有触发交互式 dismiss），
            //    例如在多个 detent 之间上下拖拽后松手 → 根据速率和位置吸附到最近的 detent。
            resolveDragEnd(velocity: velocity)
        }
    }

    var isNonInteractiveTransitioning: Bool {
        if interactiveDismissSource != .none { return false }
        return presentedViewController.isBeingPresented || presentedViewController.isBeingDismissed
    }

    var shouldApplyDownwardDampingAtSmallestDetent: Bool {
        !shouldDismiss
    }

    var sheetConfiguration: SheetConfiguration {
        configuration
    }
    
    var selectedDetentYPosition: CGFloat {
        guard let sid = selectedDetentIdentifier else { return 0 }
        return layoutInfo.yPosition(for: sid) ?? 0
    }

    func sheetInteractionDidBeginScreenEdgeInteraction(_ interaction: SheetInteraction) {
        guard shouldDismiss else {
            delegate?.presentationControllerDidAttemptToDismiss?(self)
            return
        }
        guard interactiveDismissSource == .none, !presentedViewController.isBeingDismissed else { return }

        interruptRunningSheetAnimatorIfNeeded()
        isUserInitiatedDismiss = true
        interactiveDismissSource = .screenEdge
        transitioningManager?.beginInteraction()
        presentedViewController.dismiss(animated: true)
    }

    func sheetInteraction(
        _ interaction: SheetInteraction,
        screenEdgeDidChangeProgress progress: CGFloat
    ) {
        guard interactiveDismissSource != .none else { return }
        transitioningManager?.updateInteraction(progress)
    }

    func sheetInteraction(_ interaction: SheetInteraction, screenEdgeEndedWithVelocity velocity: CGPoint) {
        guard interactiveDismissSource != .none else { return }
        let finish = shouldFinishScreenEdgeInteraction(velocity: velocity)
        completeScreenEdgeInteractiveTransition(finish: finish)
    }
}
