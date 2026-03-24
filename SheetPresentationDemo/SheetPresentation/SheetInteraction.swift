//
//  SheetInteraction.swift
//  SheetPresentationDemo
//
//  Created by 乐升平 on 2026/2/1.
//

import UIKit

// MARK: - SheetInteractionDelegate

@MainActor
protocol SheetInteractionDelegate: AnyObject {

    // MARK: 生命周期回调

    /// 拖拽开始
    func sheetInteractionDidBeginDragging(_ interaction: SheetInteraction)

    /// 拖拽过程中偏移量变化，yPosition 为 presented view 新的 Y 坐标
    func sheetInteraction(_ interaction: SheetInteraction, didChangeOffset yPosition: CGFloat)

    /// 拖拽结束
    func sheetInteraction(_ interaction: SheetInteraction, draggingEndedWithVelocity velocity: CGPoint)

    // MARK: 侧滑回调

    /// 侧滑开始
    func sheetInteractionDidBeginScreenEdgeInteraction(_ interaction: SheetInteraction)

    /// 侧滑进度变化
    /// - Parameter progress: 侧滑交互进度（0...1）
    func sheetInteraction(
        _ interaction: SheetInteraction,
        screenEdgeDidChangeProgress progress: CGFloat
    )

    /// 侧滑结束，velocity 交给 delegate 决策 finish / cancel
    func sheetInteraction(_ interaction: SheetInteraction, screenEdgeEndedWithVelocity velocity: CGPoint)

    // MARK: 状态查询

    /// 是否处于非交互式转场过程中（present 动画 / 非交互式 dismiss）
    var isNonInteractiveTransitioning: Bool { get }

    /// 在最小 detent 继续向下拖拽时，是否需要施加阻尼。
    var shouldApplyDownwardDampingAtSmallestDetent: Bool { get }

    /// 内部配置（行为相关）
    var sheetConfiguration: SheetConfiguration { get }
    
    /// 当前选中的detent的y值
    var selectedDetentYPosition: CGFloat { get }
}

// MARK: - SheetInteraction

/// 核心交互类，负责处理平移手势与 scrollView 联动。
class SheetInteraction: NSObject, UIInteraction {

    // MARK: - 代理

    weak var delegate: SheetInteractionDelegate?

    // MARK: - 布局数据

    /// Detent 的 Y 坐标数组（已排序，最小 Y → 最大 detent 在前）
    var detentYPositions: [CGFloat] = []

    /// 交互来源：用于区分当前由 scrollView 还是 sheet 自身驱动。
    private enum InteractionSource {
        case scrollViewPan
        case sheetPan
    }

    /// 最大 detent 的 Y 坐标（屏幕最靠上 → 最小值）
    private var largestDetentYPosition: CGFloat {
        detentYPositions.min() ?? 0
    }

    /// 最小 detent 的 Y 坐标（屏幕最靠下 → 最大值）
    private var smallestDetentYPosition: CGFloat {
        detentYPositions.max() ?? 0
    }
    
    // MARK: - 手势

    /// 安装在 view 上的主平移手势
    private(set) var panGestureRecognizer: UIPanGestureRecognizer!

    /// 侧滑返回手势（从屏幕左侧边缘向右拖动触发）
    private(set) var screenEdgePanGestureRecognizer: UIPanGestureRecognizer!

    /// 触点在 scrollView 内时，改由 scrollView 自己的 pan 驱动 sheet。
    private weak var boundScrollPanGesture: UIPanGestureRecognizer?

    // MARK: - 内部状态

    /// 当前触摸区域下自动检测到的 scrollView
    private(set) var currentTouchingScrollView: UIScrollView? {
        didSet {
            guard oldValue !== currentTouchingScrollView else { return }
            bindScrollView(currentTouchingScrollView)
        }
    }

    /// 收拢与 scrollView 联动相关的状态。
    private struct ScrollViewState {
        /// scrollView.panGestureRecognizer translation 的上一帧值（用于计算 delta）。
        var lastScrollPanTranslationY: CGFloat = 0

        /// 上一帧结束时 scrollView 的 contentOffset.y（用于过渡帧补偿）。
        var lastContentOffsetY: CGFloat = 0

        /// 触摸命中时的最早快照（比 began 更早）：记录初始 contentOffset.y。
        var initialContentOffsetY: CGFloat = 0

        /// changed 阶段计算结果：控制本次手势在 changed 阶段是否允许驱动 sheet。
        var canDriveSheetInChangedPhase: Bool = false

        /// 触摸开始时 scrollView 原始的竖向滚动指示器显示状态。
        var initialShowsVerticalScrollIndicator: Bool = true

    }

    private var scrollState = ScrollViewState()
    /// 当前这次手势中，是否已经发出过 begin dragging（scrollView pan 与 sheet pan 共用）。
    private var hasRespondedPanInCurrentGesture: Bool = false
    /// 已经“锁顶” 并在本次 gesture 内保持锁顶状态
    private var isTopLockLatchedInCurrentGesture: Bool = false

    /// sheetPan overpull 时追踪的原始（未压缩）Y 坐标；nil 表示当前不在 overpull 中
    private var overpullRawY: CGFloat?
    
    // MARK: - UIInteraction

    private(set) weak var view: UIView?

    // MARK: - Init

    override init() {
        super.init()

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        panGestureRecognizer = pan

        let screenEdgePan = UIPanGestureRecognizer(target: self, action: #selector(handleScreenEdgePan(_:)))
        screenEdgePan.isEnabled = false
        screenEdgePan.delegate = self
        screenEdgePan.maximumNumberOfTouches = 1
        screenEdgePanGestureRecognizer = screenEdgePan
    }
}

// MARK: - UIInteraction Protocol

extension SheetInteraction {

    func willMove(to view: UIView?) {
        if let oldView = self.view {
            oldView.removeGestureRecognizer(panGestureRecognizer)
            oldView.removeGestureRecognizer(screenEdgePanGestureRecognizer)
        }
    }

    func didMove(to view: UIView?) {
        self.view = view
        if let newView = view {
            newView.addGestureRecognizer(panGestureRecognizer)
            newView.addGestureRecognizer(screenEdgePanGestureRecognizer)
        } else {
            currentTouchingScrollView = nil
        }
    }
}


// MARK: - ScrollView Binding

extension SheetInteraction {

    /// 从触摸点沿视图层级向上查找垂直方向的 scrollView。
    private func detectScrollView(for touch: UITouch) -> UIScrollView? {
        var current: UIView? = touch.view
        while let v = current {
            if let sv = v as? UIScrollView, sv.isVerticalScrollDirection {
                return sv
            }
            if v === view { break }
            current = v.superview
        }
        return nil
    }
    
    private func bindScrollView(_ scrollView: UIScrollView?) {
        if let oldPan = boundScrollPanGesture {
            oldPan.removeTarget(self, action: #selector(handleObservedScrollPan(_:)))
            boundScrollPanGesture = nil
        }
        scrollState.lastScrollPanTranslationY = 0
        scrollState.lastContentOffsetY = 0
        hasRespondedPanInCurrentGesture = false

        guard let scrollView else { return }

        let scrollPan = scrollView.panGestureRecognizer
        scrollPan.addTarget(self, action: #selector(handleObservedScrollPan(_:)))
        boundScrollPanGesture = scrollPan
    }
}

// MARK: - 辅助方法

extension SheetInteraction {

    /// 与 detent / 上限 Y 比较时的浮点容差（pt）；一般远小于 1pt，仅吃掉 layout / 插值的亚像素级误差。
    private static let sheetYDetentComparisonTolerance: CGFloat = 0.01

    /// 当前 Y 是否处于最大 detent 位置（含容差）
    private func isAtLargestDetent(currentY: CGFloat) -> Bool {
        currentY <= largestDetentYPosition + Self.sheetYDetentComparisonTolerance
    }

    /// 当前是否为 RTL 布局（阿拉伯语等从右往左语种）
    private var isRTL: Bool {
        view?.effectiveUserInterfaceLayoutDirection == .rightToLeft
    }

    /// 锁顶规则：
    /// - 前提：仅在非最大 detent 阶段处理
    /// - 一旦进入锁顶态，结束前持续锁顶
    /// - 首次触发：
    ///   1) 触摸初始快照已到顶(==top) -> 立即锁顶
    ///   2) 触摸初始快照未到顶(>top) -> 运行中首次到达顶点或越顶(<=top)时锁顶
    private func checkAndLockToTopIfNeeded(
        currentY: CGFloat,
        velocityY: CGFloat,
        scrollView: UIScrollView
    ) {
        let maxY = maximumSheetYPosition(for: .scrollViewPan)

        if currentY <= maxY + Self.sheetYDetentComparisonTolerance {
            // isDragDown主要是为了区分scrollView.contentOffset.y == 0的下一祯是向上还是向下
            // 测试场景：prefersScrollingExpandsWhenScrolledToEdge为false的时候，从非最大detent开始上滑
            let isDragDown = velocityY > 0  // 向下滚动
            if scrollView.contentOffset.y <= scrollView.topOffsetY && isDragDown && scrollState.canDriveSheetInChangedPhase {
                scrollView.lockToTop()
                isTopLockLatchedInCurrentGesture = true
            } else {
                isTopLockLatchedInCurrentGesture = false
            }
            return
        }
        
        if isTopLockLatchedInCurrentGesture {
            scrollView.lockToTop()
            isTopLockLatchedInCurrentGesture = true
            return
        }

        let topOffsetY = scrollView.topOffsetY
        let initialOffsetY = scrollState.initialContentOffsetY
        let beganAtTop = initialOffsetY == topOffsetY
        let reachedTopFromPositive = scrollView.contentOffset.y <= topOffsetY
        if beganAtTop || (reachedTopFromPositive && scrollState.canDriveSheetInChangedPhase) {
            scrollView.lockToTop()
            isTopLockLatchedInCurrentGesture = true
            return
        }
        
    }

    /// 清理 scroll-pan 手势结束后的联动状态。
    private func clearData() {
        hasRespondedPanInCurrentGesture = false
        scrollState.lastScrollPanTranslationY = 0
        scrollState.lastContentOffsetY = 0
        scrollState.initialContentOffsetY = 0
        scrollState.canDriveSheetInChangedPhase = false
        isTopLockLatchedInCurrentGesture = false
    }

    /// 在触摸命中时初始化 scrollState，并计算 changed 阶段驱动资格。
    private func configureScrollStateForNewTouch(detectedScrollView: UIScrollView?) {
        hasRespondedPanInCurrentGesture = false
        scrollState.lastScrollPanTranslationY = 0
        scrollState.lastContentOffsetY = detectedScrollView?.contentOffset.y ?? 0
        scrollState.initialContentOffsetY = detectedScrollView?.contentOffset.y ?? 0
        scrollState.initialShowsVerticalScrollIndicator = detectedScrollView?.showsVerticalScrollIndicator ?? true
        guard let detectedScrollView, let delegate else {
            scrollState.canDriveSheetInChangedPhase = false
            isTopLockLatchedInCurrentGesture = false
            return
        }

        let tolerance: CGFloat = 5
        let config = delegate.sheetConfiguration
        if config.requiresScrollingFromEdgeToDriveSheet {
            // 这里-tolerance是一个微妙的交互优化
            // 假设topOffsetY = 0
            // 当scrollView在contentOffset.y < 0时，回弹过程中，必须要等到彻底减速到0，下一轮滚动才能驱动sheet，但是视觉上看起来是减速到0了，实际上还差几个像素，这里放宽一点，不用完全到0，在回弹到-5的位置就允许驱动sheet
            let range = (detectedScrollView.topOffsetY - tolerance)...detectedScrollView.topOffsetY
            if range.contains(scrollState.initialContentOffsetY) {
                scrollState.canDriveSheetInChangedPhase = true
            }
        } else {
            scrollState.canDriveSheetInChangedPhase = scrollState.initialContentOffsetY >= (detectedScrollView.topOffsetY - 5)
        }
        isTopLockLatchedInCurrentGesture = false
    }

    private func hideVerticalScrollIndicatorIfNeeded(for scrollView: UIScrollView) {
        scrollView.showsVerticalScrollIndicator = false
    }

    private func restoreVerticalScrollIndicatorIfNeeded(for scrollView: UIScrollView?) {
        scrollView?.showsVerticalScrollIndicator = scrollState.initialShowsVerticalScrollIndicator
    }
}

// MARK: - Observed Scroll Pan

extension SheetInteraction {

    private func shouldHandleObservedScrollPan() -> Bool {
        let config = delegate?.sheetConfiguration ?? SheetConfiguration()
        return config.allowsScrollViewToDriveSheet
            && !(delegate?.isNonInteractiveTransitioning ?? false)
    }
    
    @objc private func handleObservedScrollPan(_ gesture: UIPanGestureRecognizer) {
        guard gesture === boundScrollPanGesture else { return }
        guard let scrollView = currentTouchingScrollView else { return }
        guard shouldHandleObservedScrollPan() else { return }
        
        switch gesture.state {
        case .began, .changed:
            handleObservedScrollPanChanged(gesture, scrollView: scrollView)
        case .ended, .cancelled, .failed:
            handleObservedScrollPanEnded(gesture, scrollView: scrollView)
        default:
            break
        }
    }

    private func handleObservedScrollPanChanged(
        _ gesture: UIPanGestureRecognizer,
        scrollView: UIScrollView
    ) {
        let translationY = gesture.translation(in: gesture.view).y
        let deltaY = translationY - scrollState.lastScrollPanTranslationY
        scrollState.lastScrollPanTranslationY = translationY

        let currentY = view?.frame.origin.y ?? 0
        let prevContentOffsetY = scrollState.lastContentOffsetY

        let velocityY = gesture.velocity(in: gesture.view).y

        checkAndLockToTopIfNeeded(
            currentY: currentY,
            velocityY: velocityY,
            scrollView: scrollView)

        let canDriveSheet = canDriveSheetForObservedScrollPan(scrollView: scrollView)

        if canDriveSheet {
            notifyBeginDraggingIfNeeded()
            hideVerticalScrollIndicatorIfNeeded(for: scrollView)

            // 补偿机制的作用是解决手指在 scrollView 与 sheet 交接驱动时的“漂移”问题。
            performScrollLinkedDisplacementWithCompensation(
                deltaY: deltaY,
                previousContentOffsetY: prevContentOffsetY,
                previousSheetY: currentY,
                scrollView: scrollView
            ) { [weak self] effectiveDelta in
                guard let self else { return }

                self.applyDisplacementToSheet(
                    effectiveDelta,
                    velocity: gesture.velocity(in: gesture.view),
                    source: .scrollViewPan
                )
            }
        } else {
            restoreVerticalScrollIndicatorIfNeeded(for: scrollView)
        }
 
        // 无论是否驱动 sheet，都记录本帧最终的 contentOffset，供下一帧过渡补偿使用。
        scrollState.lastContentOffsetY = scrollView.contentOffset.y
    }

    private func canDriveSheetForObservedScrollPan(scrollView: UIScrollView) -> Bool {
        guard scrollState.canDriveSheetInChangedPhase else { return false }
        return isTopLockLatchedInCurrentGesture
    }

    private func notifyBeginDraggingIfNeeded() {
        if !hasRespondedPanInCurrentGesture {
            delegate?.sheetInteractionDidBeginDragging(self)
            hasRespondedPanInCurrentGesture = true
        }
    }

    private func handleObservedScrollPanEnded(
        _ gesture: UIPanGestureRecognizer,
        scrollView: UIScrollView
    ) {
        // 只要本次手势进入过锁顶态，结束时也锁顶
        // 如果大于等于30，说明结束那一瞬间，scrollView产生了较大位移，此时继续保持scrollView减速行为，不锁顶
        if isTopLockLatchedInCurrentGesture, scrollView.contentOffset.y < 30 {
            scrollView.lockToTop()
        }
        if hasRespondedPanInCurrentGesture {
            delegate?.sheetInteraction(self, draggingEndedWithVelocity: gesture.velocity(in: gesture.view))
        }
        clearData()
        restoreVerticalScrollIndicatorIfNeeded(for: scrollView)
    }
}

// MARK: - Sheet Pan

extension SheetInteraction {

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard delegate?.sheetConfiguration.allowsPanGestureToDriveSheet != false else { return }
        switch gesture.state {
        case .began, .changed:
            draggingChanged(gesture)
        case .ended, .cancelled, .failed:
            draggingEnded(gesture)
        default:
            break
        }
    }

    private func draggingChanged(_ gesture: UIPanGestureRecognizer) {
        guard let gestureView = gesture.view, let delegate else { return }

        let velocity = gesture.velocity(in: gestureView)
        let yDisplacement = gesture.translation(in: gestureView).y
        if !hasRespondedPanInCurrentGesture {
            delegate.sheetInteractionDidBeginDragging(self)
            hasRespondedPanInCurrentGesture = true
        }
        applyDisplacementToSheet(
            yDisplacement,
            velocity: velocity,
            source: .sheetPan
        )
        gesture.setTranslation(.zero, in: gestureView)
    }

    private func draggingEnded(_ gesture: UIPanGestureRecognizer) {
        guard let gestureView = gesture.view, let delegate else { return }

        overpullRawY = nil
        let velocity = gesture.velocity(in: gestureView)
        delegate.sheetInteraction(self, draggingEndedWithVelocity: velocity)
        hasRespondedPanInCurrentGesture = false
    }
}

// MARK: - Screen Edge Pan

extension SheetInteraction {

    @objc private func handleScreenEdgePan(_ gesture: UIPanGestureRecognizer) {
        guard let delegate else { return }
        guard !delegate.isNonInteractiveTransitioning else { return }

        switch gesture.state {
        case .began:
            delegate.sheetInteractionDidBeginScreenEdgeInteraction(self)

        case .changed:
            // LTR：从左边缘向右滑，translationX 为正；RTL：从右边缘向左滑，translationX 为负，取反后统一为正值。
            // 滑满一整屏宽度 → progress = 1（完全 dismiss）。
            let window = gesture.view?.window
            let rawTranslationX = gesture.translation(in: window).x
            let effectiveTranslationX = isRTL ? -rawTranslationX : rawTranslationX
            let screenWidth = window?.bounds.width ?? UIScreen.main.bounds.width
            let progress = min(max(effectiveTranslationX / screenWidth, 0), 1)
            delegate.sheetInteraction(self, screenEdgeDidChangeProgress: progress)

        case .ended, .cancelled, .failed:
            let velocity = gesture.velocity(in: gesture.view)
            delegate.sheetInteraction(self, screenEdgeEndedWithVelocity: velocity)

        default:
            break
        }
    }
}

// MARK: - Sheet Displacement

extension SheetInteraction {

    private func applyDisplacementToSheet(
        _ yDisplacement: CGFloat,
        velocity: CGPoint,
        source: InteractionSource
    ) {
        let currentY = view?.frame.origin.y ?? 0
        var displacement = yDisplacement
        let dampingFactor = calculateDampingFactor(
            velocity: velocity,
            currentY: currentY,
            source: source
        )
        displacement *= dampingFactor
        let newY = currentY + displacement

        let maxY = maximumSheetYPosition(for: source)
        let clampedY = max(newY, maxY)
        delegate?.sheetInteraction(self, didChangeOffset: clampedY)
    }

    /// 计算本帧允许的最小 Y（越小越靠上）。
    /// 当 expandsWhenScrolledToEdge 关闭时，上限固定在当前选中 detent。
    private func maximumSheetYPosition(for source: InteractionSource) -> CGFloat {
        guard let delegate = delegate else {
            return largestDetentYPosition
        }
        let config = delegate.sheetConfiguration
        switch source {
        case .scrollViewPan:
            return config.prefersScrollingExpandsWhenScrolledToEdge
                ? largestDetentYPosition
                : delegate.selectedDetentYPosition
        case .sheetPan:
            guard config.prefersSheetPanOverpullWithDamping else {
                return largestDetentYPosition
            }
            // 最多允许向上 overpull 100pt，超出后完全禁止继续上移。否则2只手交替往上滑动，阻尼再强也阻止不了.
            return largestDetentYPosition - 100
        }
    }

    /// Scroll 联动一体化补偿：
    /// - 前补偿：扣除本帧被 scrollView 先消费的位移
    /// - 执行位移：通过闭包调用 applyDisplacementToSheet
    /// - 后补偿：若 sheet 无法继续上移，将溢出位移回填给 scrollView
    private func performScrollLinkedDisplacementWithCompensation(
        deltaY: CGFloat,
        previousContentOffsetY: CGFloat,
        previousSheetY: CGFloat,
        scrollView: UIScrollView,
        applyDisplacement: (CGFloat) -> Void
    ) {
        let topOffsetY = scrollView.topOffsetY
        let effectiveDelta: CGFloat
        if previousContentOffsetY > topOffsetY {
            let scrollConsumed = previousContentOffsetY - topOffsetY
            effectiveDelta = deltaY - scrollConsumed
        } else {
            effectiveDelta = deltaY
        }

        applyDisplacement(effectiveDelta)

        guard effectiveDelta < 0 else { return }
        let newSheetY = view?.frame.origin.y ?? 0
        let scrollMaxY = maximumSheetYPosition(for: .scrollViewPan)
        guard newSheetY <= scrollMaxY + Self.sheetYDetentComparisonTolerance else { return }

        let sheetMoved = previousSheetY - newSheetY
        let fingerMoved = -effectiveDelta
        let overflow = fingerMoved - sheetMoved
        guard overflow > 0 else { return }

        let newOffset = max(scrollView.contentOffset.y + overflow, scrollView.topOffsetY)
        scrollView.setContentOffset(
            CGPoint(x: scrollView.contentOffset.x, y: newOffset),
            animated: false
        )
    }
}

// MARK: - 阻尼计算

extension SheetInteraction {

    /// 计算阻尼系数。
    /// - 在最小 detent 向下拖拽且需要阻尼时：采用连续阻尼（越往下拖，阻尼越强）
    /// - 在最大 detent 向上拖拽且开启 overpull 时：采用连续阻尼（越往上拖，阻尼越强）
    private func calculateDampingFactor(
        velocity: CGPoint,
        currentY: CGFloat,
        source: InteractionSource
    ) -> CGFloat {
        if let factor = downwardDampingFactor(velocity: velocity, currentY: currentY) {
            return factor
        }
        if let factor = overpullDampingFactor(velocity: velocity, currentY: currentY, source: source) {
            return factor
        }
        return 1.0
    }

    /// 向下拖拽越过最小 detent 时的阻尼：越往下越强，最低 0.18
    private func downwardDampingFactor(velocity: CGPoint, currentY: CGFloat) -> CGFloat? {
        guard velocity.y > 0,
              delegate?.shouldApplyDownwardDampingAtSmallestDetent == true,
              currentY >= smallestDetentYPosition else { return nil }
        let overflow = currentY - smallestDetentYPosition
        return decayingFactor(overflow: overflow, initial: 1.0, decay: 0.05, minimum: 0.18)
    }

    /// sheetPan overpull 向上拖拽越过最大 detent 时的阻尼：从边界第一帧就强，越往上越强，最低 0.04
    private func overpullDampingFactor(velocity: CGPoint, currentY: CGFloat, source: InteractionSource) -> CGFloat? {
        guard velocity.y < 0,
              source == .sheetPan,
              delegate?.sheetConfiguration.prefersSheetPanOverpullWithDamping == true,
              currentY <= largestDetentYPosition else { return nil }
        let overflow = largestDetentYPosition - currentY
        return decayingFactor(overflow: overflow, initial: 0.3, decay: 0.01, minimum: 0.04)
    }

    /// 通用衰减阻尼公式：initial / (1 + decay × overflow)，不低于 minimum。
    private func decayingFactor(overflow: CGFloat, initial: CGFloat, decay: CGFloat, minimum: CGFloat) -> CGFloat {
        return max(minimum, initial / (1.0 + decay * overflow))
    }
}

// MARK: - UIGestureRecognizerDelegate

extension SheetInteraction: UIGestureRecognizerDelegate {

    /// 是否接收触摸：自动检测 scrollView，重置手势状态
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        guard gestureRecognizer === panGestureRecognizer else { return true }

        let detected = detectScrollView(for: touch)
        if detected !== currentTouchingScrollView {
            currentTouchingScrollView = detected
        }
        if let detected, detected.isDragging {
            return false
        }

        configureScrollStateForNewTouch(detectedScrollView: detected)

        return true
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else { return true }

        if gestureRecognizer === panGestureRecognizer {
            guard delegate?.sheetConfiguration.allowsPanGestureToDriveSheet != false else { return false }
            let velocity = panGesture.velocity(in: panGesture.view)
            guard abs(velocity.y) > 0 else { return true }
            let ratio = abs(velocity.x) / abs(velocity.y)
            let shouldLimitHorizontalRatio = screenEdgePanGestureRecognizer.isEnabled == true
            if shouldLimitHorizontalRatio, ratio > 2 {
                if currentTouchingScrollView?.panGestureRecognizer.isEnabled == true {
                    currentTouchingScrollView?.panGestureRecognizer.isEnabled = false
                    currentTouchingScrollView?.panGestureRecognizer.isEnabled = true
                }
                return false
            }
            guard currentTouchingScrollView == nil else { return false }
            return true
        }

        if gestureRecognizer === screenEdgePanGestureRecognizer {
            guard let delegate else { return false }
            let config = delegate.sheetConfiguration
            guard !delegate.isNonInteractiveTransitioning else { return false }

            // 起点必须在距 leading 边缘的有效范围内（LTR：左边缘，RTL：右边缘）
            let window = panGesture.view?.window
            let windowX = panGesture.location(in: window).x
            let screenWidth = window?.bounds.width ?? UIScreen.main.bounds.width
            let maxDistance = config.edgePanTriggerDistance
            let isNearLeadingEdge = isRTL
                ? windowX >= screenWidth - maxDistance
                : windowX <= maxDistance
            guard isNearLeadingEdge else { return false }

            // 主方向必须朝 trailing 方向（LTR：向右，RTL：向左），且水平分量主导
            let velocity = panGesture.velocity(in: panGesture.view)
            guard isRTL ? velocity.x < 0 : velocity.x > 0 else { return false }
            guard abs(velocity.x) >= abs(velocity.y) else { return false }

            return true
        }

        return true
    }
}

// MARK: - UIScrollView Helpers

fileprivate extension UIScrollView {

    /// 内容处于顶部时的 adjustedContentInset.y（即 -adjustedContentInset.top）
    var topOffsetY: CGFloat { -adjustedContentInset.top }

    /// 将内容锁顶
    func lockToTop() {
        setContentOffset(CGPoint(x: contentOffset.x, y: topOffsetY), animated: false)
    }

    /// 竖直方向内容是否超出当前可视区域（可真正产生纵向滚动）
    private var hasVerticalContentOverflow: Bool {
        let inset = adjustedContentInset
        let visibleHeight = bounds.height - inset.top - inset.bottom
        guard visibleHeight > 0 else { return contentSize.height > 0 }
        return contentSize.height > visibleHeight + 0.5
    }

    /// 水平方向内容是否超出当前可视区域
    private var hasHorizontalContentOverflow: Bool {
        let inset = adjustedContentInset
        let visibleWidth = bounds.width - inset.left - inset.right
        guard visibleWidth > 0 else { return contentSize.width > 0 }
        return contentSize.width > visibleWidth + 0.5
    }

    /// 是否应作为「纵向 scroll 驱动 Sheet」的候选：`alwaysBounceVertical` 为 true 时系统仍会处理竖直 pan；
    /// 否则仅在内容高于可视区域时才交给 scrollView 的 pan，避免短内容且不弹跳时吃掉触摸、Sheet 平移无法触发。
    private var canActAsVerticalScrollDriver: Bool {
        alwaysBounceVertical || hasVerticalContentOverflow
    }

    /// 判断 scrollView 的主轴是否为垂直滚动方向
    var isVerticalScrollDirection: Bool {
        guard isScrollEnabled else { return false }
        if self is UITableView {
            return canActAsVerticalScrollDriver
        }

        if let collectionView = self as? UICollectionView {
            if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                guard flowLayout.scrollDirection == .vertical else { return false }
                return canActAsVerticalScrollDriver
            }
            if let compositionalLayout =
                collectionView.collectionViewLayout as? UICollectionViewCompositionalLayout {
                guard compositionalLayout.configuration.scrollDirection == .vertical else { return false }
                return canActAsVerticalScrollDriver
            }
        }

        let verticalOverflow = hasVerticalContentOverflow
        let horizontalOverflow = hasHorizontalContentOverflow

        if verticalOverflow && !horizontalOverflow { return canActAsVerticalScrollDriver }
        if horizontalOverflow && !verticalOverflow { return false }

        return canActAsVerticalScrollDriver
    }
}
