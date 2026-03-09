//
//  SheetPresentationController.swift
//  SheetPresentation
//
//  Created by 乐升平 on 2026/1/30.
//

import UIKit

// MARK: - Detent & Identifier

extension SheetPresentationController.Detent {

    public struct Identifier: Hashable, Equatable, RawRepresentable {
        public var rawValue: String

        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
}

extension SheetPresentationController.Detent.Identifier {

    public static let medium: SheetPresentationController.Detent.Identifier = .init("medium")
    public static let large: SheetPresentationController.Detent.Identifier = .init("large")
}

// MARK: - Detent Resolution Context

@MainActor public protocol SheetPresentationControllerDetentResolutionContext: NSObjectProtocol {
    var containerTraitCollection: UITraitCollection { get }
    var maximumDetentValue: CGFloat { get }
}

// MARK: - Detent

@MainActor
extension SheetPresentationController {

    open class Detent: NSObject {

        open var identifier: Identifier
        open var height: CGFloat
        private var heightResolver: ((_ context: any SheetPresentationControllerDetentResolutionContext) -> CGFloat?)?

        init(identifier: Identifier, height: CGFloat) {
            self.identifier = identifier
            self.height = height
        }

        public static func medium() -> Detent {
            .custom(identifier: .medium) { $0.maximumDetentValue * 0.5 }
        }

        public static func large() -> Detent {
            .custom(identifier: .large) { $0.maximumDetentValue - 50 }
        }

        @MainActor @preconcurrency
        public static func custom(
            identifier: SheetPresentationController.Detent.Identifier? = nil,
            resolver: @escaping (_ context: any SheetPresentationControllerDetentResolutionContext) -> CGFloat?
        ) -> SheetPresentationController.Detent {
            let id = identifier ?? .init("custom")
            return Detent(identifier: id, heightResolver: resolver)
        }

        @MainActor @preconcurrency
        public func resolvedValue(
            in context: any SheetPresentationControllerDetentResolutionContext
        ) -> CGFloat? {
            heightResolver?(context)
        }

        private init(
            identifier: Identifier,
            heightResolver: @escaping (_ context: any SheetPresentationControllerDetentResolutionContext) -> CGFloat?
        ) {
            self.identifier = identifier
            self.heightResolver = heightResolver
            self.height = 0
        }
    }
}

// MARK: - SheetPresentationControllerDelegate

@MainActor
@objc public protocol SheetPresentationControllerDelegate: UIAdaptivePresentationControllerDelegate {
    /// 当前选中的 detent 发生变化时调用
    @objc optional func sheetPresentationControllerDidChangeSelectedDetentIdentifier(
        _ sheetPresentationController: SheetPresentationController
    )
}

// MARK: - SheetPresentationController

@MainActor
open class SheetPresentationController: UIPresentationController {

    // MARK: - Detent 配置

    /// 多段高度配置
    open var detents: [Detent] = [.large()] {
        didSet {
            layoutInfo.detents = detents
            layoutInfo.invalidateDetents()
            syncDetentYPositionsToInteraction()
        }
    }

    /// 当前选中的 detent 标识符。
    /// 直接设置不带动画（立即跳到目标位置）；
    /// 需要动画时请使用 `animateChanges(_:)` 包裹。
    open var selectedDetentIdentifier: Detent.Identifier? {
        get { _selectedDetentIdentifier }
        set { setSelectedDetent(newValue, animated: false) }
    }

    // MARK: - 行为配置

    /// 是否允许点击背景蒙层 dismiss，默认 true
    open var allowsTapBackgroundToDismiss: Bool {
        get { configuration.allowsTapBackgroundToDismiss }
        set { configuration.allowsTapBackgroundToDismiss = newValue }
    }

    /// 手势驱动模式（scroll / pan），默认 both。
    open var sheetDrivingMode: SheetPresentationController.DrivingMode {
        get { configuration.sheetDrivingMode }
        set { configuration.sheetDrivingMode = newValue }
    }

    /// 是否要求必须从 edge 开始滚动，scrollView 才能驱动 sheet，默认 false
    open var requiresScrollingFromEdgeToDriveSheet: Bool {
        get { configuration.requiresScrollingFromEdgeToDriveSheet }
        set { configuration.requiresScrollingFromEdgeToDriveSheet = newValue }
    }

    /// 处于非最大高度时，scrollView 滑到边缘是否可带动 sheet 展开，默认 true
    open var prefersScrollingExpandsWhenScrolledToEdge: Bool {
        get { configuration.prefersScrollingExpandsWhenScrolledToEdge }
        set { configuration.prefersScrollingExpandsWhenScrolledToEdge = newValue }
    }

    /// 是否允许穿透
    open var allowsTouchEventsPassingThroughTransitionView: Bool = false

    // MARK: - 外观配置

    /// 顶部圆角数值，默认 10.0
    open var preferredCornerRadius: CGFloat = 10.0 {
        didSet { dropShadowView?.cornerRadius = preferredCornerRadius }
    }

    /// 是否显示阴影，默认 false
    open var prefersShadowVisible: Bool = false {
        didSet { dropShadowView?.isShadowVisible = prefersShadowVisible }
    }

    /// 是否显示顶部抓取条，默认 false
    open var prefersGrabberVisible: Bool = false {
        didSet { dropShadowView?.isGrabberVisible = prefersGrabberVisible }
    }

    /// 背景蒙层不透明度，默认 0.4
    open var dimmingBackgroundAlpha: CGFloat = 0.4 {
        didSet { dimmingView?.backgroundAlpha = dimmingBackgroundAlpha }
    }

    /// present / dismiss 转场时长，默认 0.3s
    open var transitionAnimationDuration: TimeInterval = 0.3

    // MARK: - 侧滑返回

    /// 是否允许侧滑返回
    open var allowScreenEdgeInteractive: Bool {
        get { configuration.allowScreenEdgeInteractive }
        set { configuration.allowScreenEdgeInteractive = newValue }
    }

    /// 侧滑有效触发距离
    open var maxAllowedDistanceToScreenEdgeForPanInteraction: CGFloat {
        get { configuration.maxAllowedDistanceToScreenEdgeForPanInteraction }
        set { configuration.maxAllowedDistanceToScreenEdgeForPanInteraction = newValue }
    }
    
    /// 在此闭包中修改属性（如 `selectedDetentIdentifier`）会自动带动画过渡。
    open func animateChanges(_ changes: @escaping () -> Void) {
        animateChanges(changes, completion: nil)
    }

    // MARK: - Internal Properties

    private var _selectedDetentIdentifier: Detent.Identifier?

    /// 布局信息
    private(set) var layoutInfo = SheetLayoutInfo()

    /// 内部配置
    private var configuration = SheetConfiguration()

    /// 平移结束时可触发 dismiss 的最小垂直速率，默认 800
    private var minVerticalVelocityToTriggerDismiss: CGFloat = 800
    
    /// 背景蒙层
    private var dimmingView: SheetDimmingView?

    /// 阴影容器视图
    private var dropShadowView: DropShadowView?

    /// 交互控制器
    private(set) var sheetInteraction: SheetInteraction?

    /// 当前进行中的 sheet 动画（用于手势接管时中断）。
    private var sheetAnimator: UIViewPropertyAnimator?

    /// 是否正在拖拽（阻止 layout 重置 frame）
    private var isDragging = false

    /// 是否正在进行交互式 dismiss 转场（拖拽越过最小 detent 触发）。
    private var isDraggingAndTransitioning = false

    /// detent 吸附动画进行中。
    private var isAnimatingToDetent = false

    /// 标记当前 dismiss 是否由用户操作触发（拖拽/点击蒙层）。
    /// 外部代码直接调用 dismiss 时，不转发 UIAdaptivePresentationControllerDelegate 回调。
    /// 用于决定是否转发 UIAdaptivePresentationControllerDelegate 的回调。
    private var isUserInitiatedDismiss = false

    /// 转场管理器（通过 presentedViewController 关联获取）
    private var transitioningManager: SheetTransitioningManager? {
        presentedViewController.cs.transitioningManager
    }

    /// 将 delegate 转为 SheetPresentationControllerDelegate（外部未遵循则为 nil）
    private var sheetDelegate: SheetPresentationControllerDelegate? {
        delegate as? SheetPresentationControllerDelegate
    }

    // MARK: - Lifecycle

    public override init(
        presentedViewController: UIViewController,
        presenting presentingViewController: UIViewController?
    ) {
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
    }

    // MARK: - Presentation Lifecycle

    open override func presentationTransitionWillBegin() {
        super.presentationTransitionWillBegin()
        guard let containerView else { return }

        // 配置 layoutInfo
        refreshLayoutInfo(using: containerView, invalidateDetents: true)

        // 确保有选中的 detent：默认选择最小 detent（最靠近底部、Y 最大）
        if selectedDetentIdentifier == nil,
           let smallest = layoutInfo.sortedDetentEntries.last {
            setSelectedDetent(smallest.identifier, animated: false)
        }

        setupViews()

        // 带转场协调器渐入蒙层
        dimmingView?.alpha = 0
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { [weak self] _ in
            self?.dimmingView?.alpha = 1
        })
    }

    open override func presentationTransitionDidEnd(_ completed: Bool) {
        super.presentationTransitionDidEnd(completed)
        if !completed {
            cleanupViews()
        }
    }

    open override func dismissalTransitionWillBegin() {
        super.dismissalTransitionWillBegin()

        // 仅用户操作触发的 dismiss 才转发 willDismiss
        if isUserInitiatedDismiss {
            delegate?.presentationControllerWillDismiss?(self)
        }

        // 交互式 dismiss 时蒙层由手动 updateDimmingForPosition 控制，不使用 coordinator。
        // 非交互式 dismiss（如点击蒙层、代码调用）使用 coordinator 渐出。
        if !isDraggingAndTransitioning {
            presentedViewController.transitionCoordinator?.animate(alongsideTransition: { [weak self] _ in
                self?.dimmingView?.alpha = 0
            })
        }
    }

    open override func dismissalTransitionDidEnd(_ completed: Bool) {
        super.dismissalTransitionDidEnd(completed)
        if completed {
            // 仅用户操作触发的 dismiss 完成后才转发 didDismiss
            if isUserInitiatedDismiss {
                delegate?.presentationControllerDidDismiss?(self)
            }
            cleanupViews()
        } else {
            // 交互式 dismiss 被取消：cancelInteraction() → 反向动画跑完 → completeTransition(false) → UIKit 回调此处。
            // 在此重置 isDraggingAndTransitioning，确保下次用户越过 smallestDetentY 时能重新触发 beginInteractiveDismiss。
            isDraggingAndTransitioning = false
        }
        isUserInitiatedDismiss = false
    }

    // MARK: - Layout

    open override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()

        dimmingView?.frame = containerView?.bounds ?? .zero

        let allowFrameUpdate = !isDragging && !isDraggingAndTransitioning && !isAnimatingToDetent
        if allowFrameUpdate, let shadowView = dropShadowView {
            shadowView.frame = self.frameOfPresentedViewInContainerView
        }
    }

    open override var presentedView: UIView? {
        dropShadowView
    }

    open override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView else { return .zero }

        // 更新 layoutInfo 的 containerBounds（以防旋转）
        if layoutInfo.containerBounds != containerView.bounds {
            refreshLayoutInfo(using: containerView, invalidateDetents: false)
        }

        return layoutInfo.frameOfPresentedView(for: selectedDetentIdentifier)
    }

    // MARK: - View Setup

    private func setupViews() {
        guard let containerView else { return }

        // 背景蒙层
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

        // 阴影容器
        let shadowView = DropShadowView()
        shadowView.cornerRadius = preferredCornerRadius
        shadowView.isShadowVisible = prefersShadowVisible
        shadowView.isGrabberVisible = prefersGrabberVisible
        containerView.addSubview(shadowView)
        dropShadowView = shadowView

        // 将 presentedViewController.view 嵌入 contentView
        let controllerView = presentedViewController.view!
        controllerView.frame = shadowView.contentView.bounds
        controllerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        shadowView.contentView.addSubview(controllerView)

        // 添加 SheetInteraction
        let interaction = SheetInteraction()
        interaction.delegate = self
        shadowView.addInteraction(interaction)
        sheetInteraction = interaction

        // 同步 detent Y 坐标到 interaction（行为配置通过 delegate.sheetConfiguration 按需读取）
        syncDetentYPositionsToInteraction()

        // 配置 grabber 点击（在 detent 间切换）
        shadowView.grabberDidClickHandler = { [weak self] in
            self?.toggleNextDetent()
        }
    }

    private func cleanupViews() {
        dimmingView?.removeFromSuperview()
        dimmingView = nil
        if let interaction = sheetInteraction {
            dropShadowView?.removeInteraction(interaction)
        }
        sheetInteraction = nil
        dropShadowView?.removeFromSuperview()
        dropShadowView = nil
    }

    // MARK: - 属性同步

    /// 同步 detent Y 坐标到 SheetInteraction。
    /// 行为配置（SheetConfiguration）由 interaction 通过 delegate.sheetConfiguration 按需读取，无需手动同步。
    private func syncDetentYPositionsToInteraction() {
        sheetInteraction?.detentYPositions = layoutInfo.sortedDetentEntries.map(\.yPosition)
    }

    private func refreshLayoutInfo(using containerView: UIView, invalidateDetents: Bool) {
        layoutInfo.containerBounds = containerView.bounds
        layoutInfo.containerSafeAreaInsets = containerView.safeAreaInsets
        layoutInfo.containerTraitCollection = containerView.traitCollection
        if invalidateDetents {
            layoutInfo.detents = detents
            layoutInfo.invalidateDetents()
        }
    }

    // MARK: - Detent Management

    /// 设置选中的 detent 标识符，可选是否带动画。
    /// 类似 `UIScrollView.setContentOffset(_:animated:)`。
    /// animated = true 时弹簧动画过渡，animated = false 时直接跳到目标位置。
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

    /// 直接根据 Y 更新 presentedView 的 frame（无动画）。
    private func updatePresentedViewFrame(forYPosition yPosition: CGFloat) {
        guard let shadowView = dropShadowView else { return }
        shadowView.frame = layoutInfo.frameOfPresentedView(at: yPosition)
    }

    /// 动画切换到指定 detent（对齐 OC：动画期直接驱动 frame，不依赖 layoutIfNeeded 触发回调）。
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
            // 动画结束后标记下一轮容器布局对齐。
            self.containerView?.setNeedsLayout()
        })
    }
    
    /// 内部版本：允许带 completion，供控制器内部收尾逻辑使用。
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

    /// 点击 grabber 切换 detent：
    /// - 当前非最大 detent：向上一档
    /// - 当前最大 detent：跳到最小 detent
    private func toggleNextDetent() {
        guard let currentId = selectedDetentIdentifier else { return }
        let targetId: Detent.Identifier?
        if let upperEntry = layoutInfo.relativeEntry(from: currentId, offset: -1) {
            // 非最大 detent：固定向上一档（例如 medium -> large）
            targetId = upperEntry.identifier
        } else {
            // 最大 detent：跳到最小 detent
            targetId = layoutInfo.sortedDetentEntries.last?.identifier
        }
        guard let targetId else { return }
        setSelectedDetent(targetId, animated: true)
    }

    // MARK: - 拖拽结束逻辑

    /// 拖拽结束后根据速率和位置决定目标 detent 或 dismiss。
    private func resolveDragEnd(velocity: CGPoint) {
        guard let shadowView = dropShadowView else { return }

        let currentY = shadowView.frame.origin.y
        let isHighVelocity = abs(velocity.y) >= minVerticalVelocityToTriggerDismiss

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

    /// 高速向上拖拽：切换到更大的 detent
    private func resolveHighVelocityDragUp(from currentY: CGFloat) {
        guard let currentId = selectedDetentIdentifier else {
            snapToNearest(from: currentY)
            return
        }
        guard let currentEntry = layoutInfo.entry(for: currentId) else {
            snapToNearest(from: currentY)
            return
        }

        // 松手时位置未越过当前 detent（仍在其下方），速率再高也只弹回当前 detent。
        // 例如：medium 状态向下拖后高速上滑，但松手时 currentY 仍大于 mediumY → 回到 medium。
        guard currentY < currentEntry.yPosition else {
            setSelectedDetent(currentId, animated: true)
            return
        }

        guard let previousEntry = layoutInfo.relativeEntry(from: currentId, offset: -1) else {
            // 已在最大 detent → 弹回
            setSelectedDetent(currentId, animated: true)
            return
        }

        // 如果已拖过 prevEntry → 再上一档
        if currentY < previousEntry.yPosition,
           let target = layoutInfo.relativeEntry(from: currentId, offset: -2) {
            setSelectedDetent(target.identifier, animated: true)
        } else {
            setSelectedDetent(previousEntry.identifier, animated: true)
        }
    }

    /// 高速向下拖拽：切换到更小的 detent 或 dismiss
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
            // 已在最小 detent
            // 若松手位置仍在当前最小 detent 上方（例如先上拉到其上方再高速向下），
            // 应先回到当前 detent，而不是直接 dismiss。
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

    // MARK: - 交互式 Dismiss 转场
    //
    // - 拖拽越过 smallestDetentYPosition → beginInteractiveDismiss()
    private func beginInteractiveDismiss() {
        isUserInitiatedDismiss = true
        isDraggingAndTransitioning = true
        transitioningManager?.beginInteraction()
        presentedViewController.dismiss(animated: true)
    }

    /// 完成交互式 dismiss 转场。
    /// - finish 时：finishInteraction 与 performDismissAnimation 并发运行。
    /// - cancel 时：取消交互转场并回到最近的 detent。
    private func completeInteractiveTransition(finish: Bool, velocity: CGPoint) {
        isDraggingAndTransitioning = false

        if finish {
            // 剩余动画时长 = (1 - percentComplete) * 完整时长
            // finishInteraction 默认以 completionSpeed=1 播完剩余段，与 performDismissAnimation 保持一致。
            let fullDuration: TimeInterval = 0.25
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

    // MARK: - Dimming

    /// 根据当前 Y 位置更新蒙层透明度（仅在拖拽超过最小 detent 时淡出）
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
            if !isDraggingAndTransitioning
                && yPosition > smallestDetentY && !presentedViewController.isBeingDismissed {
                // 首次越过最小 detent → 开始交互式 dismiss
                beginInteractiveDismiss()
            }

            if isDraggingAndTransitioning {
                let totalRange = containerView.bounds.height - smallestDetentY
                if totalRange > 0 {
                    let progress = (yPosition - smallestDetentY) / totalRange
                    let percent = min(max(progress, 0.0), 1.0)
                    transitioningManager?.updateInteraction(percent)
                }
            }
        }

        // 更新 frame
        updatePresentedViewFrame(forYPosition: yPosition)

        updateDimmingForPosition(yPosition)
    }

    func sheetInteraction(_ interaction: SheetInteraction, draggingEndedWithVelocity velocity: CGPoint) {
        isDragging = false
        // 手势驱动阶段我们通过 frame 直接更新 dropShadowView；而内容子视图可能是 Auto Layout。
        // 松手到进入 animateToDetent 的交接瞬间，父视图位置通常已经是最新，但子约束可能仍停留在上一轮 layout pass，
        // 从而出现“父视图先动、子控件慢一帧”的视觉不同步。
        // 这里先强制把 presentedViewController.view 的约束同步到当前帧，消除交接窗口，再进入后续吸附/dismiss 决策。
        presentedViewController.view.setNeedsLayout()
        presentedViewController.view.layoutIfNeeded()

        if isDraggingAndTransitioning {

            // ── 分支 1：交互式 dismiss 进行中（曾越过 smallestDetent），手指抬起。
            // 根据当前位置和速率决定 finish 或 cancel。
            let currentY = dropShadowView?.frame.origin.y ?? 0
            let containerHeight = containerView?.bounds.height ?? UIScreen.main.bounds.height
            let isBelow = currentY > layoutInfo.smallestDetentYPosition
            let isHighVelocity = velocity.y >= minVerticalVelocityToTriggerDismiss
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
        if isDraggingAndTransitioning { return false }
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
}
