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

    // MARK: - 布局数据

    /// Detent 的 Y 坐标数组（已排序，最小 Y → 最大 detent 在前）
    var detentYPositions: [CGFloat] = []

    /// 位移来源：用于区分来自 scrollView 的联动，还是 sheet 自身的平移手势。
    private enum DisplacementSource {
        case scrollViewPan
        case sheetPan
    }

    // MARK: - 计算属性

    /// 最大 detent 的 Y 坐标（屏幕最靠上 → 最小值）
    var largestDetentYPosition: CGFloat {
        detentYPositions.min() ?? 0
    }

    /// 最小 detent 的 Y 坐标（屏幕最靠下 → 最大值）
    var smallestDetentYPosition: CGFloat {
        detentYPositions.max() ?? 0
    }

    // MARK: - 代理

    weak var delegate: SheetInteractionDelegate?

    // MARK: - 手势

    /// 安装在 view 上的主平移手势
    private(set) var panGestureRecognizer: UIPanGestureRecognizer!

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
        var initialContentOffsetYAtTouchStart: CGFloat = 0

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

    // MARK: - UIInteraction

    private(set) weak var view: UIView?

    // MARK: - Init

    override init() {
        super.init()

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        panGestureRecognizer = pan
    }
}

// MARK: - UIInteraction Protocol

extension SheetInteraction {

    func willMove(to view: UIView?) {
        if let oldView = self.view {
            oldView.removeGestureRecognizer(panGestureRecognizer)
        }
    }

    func didMove(to view: UIView?) {
        self.view = view
        if let newView = view {
            newView.addGestureRecognizer(panGestureRecognizer)
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

    /// 当前 Y 是否处于最大 detent 位置（容差 1pt）
    private func isAtLargestDetent(currentY: CGFloat) -> Bool {
        currentY <= largestDetentYPosition + 1
    }

    private func lockToTopAndRemember(_ scrollView: UIScrollView) {
        scrollView.lockToTop()
        isTopLockLatchedInCurrentGesture = true
    }

    /// 锁顶规则：
    /// - 前提：仅在非最大 detent 阶段处理
    /// - 一旦进入锁顶态，结束前持续锁顶
    /// - 首次触发：
    ///   1) 触摸初始快照已到顶(==top) -> 立即锁顶
    ///   2) 触摸初始快照未到顶(>top) -> 运行中首次到达顶点或越顶(<=top)时锁顶
    private func checkAndLockToTopIfNeeded(
        currentY: CGFloat,
        scrollView: UIScrollView
    ) {
        let maxY = maximumSheetYPosition(for: .scrollViewPan)
        guard currentY > maxY else {
            isTopLockLatchedInCurrentGesture = false
            return
        }

        if isTopLockLatchedInCurrentGesture {
            lockToTopAndRemember(scrollView)
            return
        }

        let topOffsetY = scrollView.topOffsetY
        let initialOffsetY = scrollState.initialContentOffsetYAtTouchStart
        let beganAtTop = initialOffsetY == topOffsetY
        let reachedTopFromPositive = initialOffsetY > topOffsetY
            && scrollView.contentOffset.y <= topOffsetY
        if beganAtTop || (reachedTopFromPositive && scrollState.canDriveSheetInChangedPhase) {
            lockToTopAndRemember(scrollView)
        }
    }

    /// 清理 scroll-pan 手势结束后的联动状态。
    private func clearData() {
        hasRespondedPanInCurrentGesture = false
        scrollState.lastScrollPanTranslationY = 0
        scrollState.lastContentOffsetY = 0
        scrollState.initialContentOffsetYAtTouchStart = 0
        scrollState.canDriveSheetInChangedPhase = false
        isTopLockLatchedInCurrentGesture = false
    }

    /// 在触摸命中时初始化 scrollState，并计算 changed 阶段驱动资格。
    private func configureScrollStateForNewTouch(detectedScrollView: UIScrollView?) {
        hasRespondedPanInCurrentGesture = false
        scrollState.lastScrollPanTranslationY = 0
        scrollState.lastContentOffsetY = detectedScrollView?.contentOffset.y ?? 0
        scrollState.initialContentOffsetYAtTouchStart = detectedScrollView?.contentOffset.y ?? 0
        scrollState.initialShowsVerticalScrollIndicator = detectedScrollView?.showsVerticalScrollIndicator ?? true
        guard let detectedScrollView, let delegate else {
            scrollState.canDriveSheetInChangedPhase = false
            isTopLockLatchedInCurrentGesture = false
            return
        }

        let config = delegate.sheetConfiguration
        if config.requiresScrollingFromEdgeToDriveSheet {
            scrollState.canDriveSheetInChangedPhase =
                scrollState.initialContentOffsetYAtTouchStart == detectedScrollView.topOffsetY
        } else {
            scrollState.canDriveSheetInChangedPhase =
                scrollState.initialContentOffsetYAtTouchStart >= detectedScrollView.topOffsetY
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

    private func shouldHandleObservedScrollPan() -> Bool {
        let config = delegate?.sheetConfiguration ?? SheetConfiguration()
        return config.sheetDrivingMode.allowsScrollDriving
            && !(delegate?.isNonInteractiveTransitioning ?? false)
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

        checkAndLockToTopIfNeeded(currentY: currentY, scrollView: scrollView)

        let velocityY = gesture.velocity(in: gesture.view).y
        let canDriveSheet = canDriveSheetForObservedScrollPan(
            velocityY: velocityY,
            scrollView: scrollView
        )

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

    private func canDriveSheetForObservedScrollPan(
        velocityY: CGFloat,
        scrollView: UIScrollView
    ) -> Bool {
        guard scrollState.canDriveSheetInChangedPhase else { return false }

        // isDragDown主要是为了区分scrollView.contentOffset.y == 0的下一祯是向上还是向下
        // 测试场景：prefersScrollingExpandsWhenScrolledToEdge为false的时候，从非最大detent开始上滑
        let isDragDown = velocityY > 0 // 向下滚动
        return isTopLockLatchedInCurrentGesture
            || (scrollView.contentOffset.y <= scrollView.topOffsetY && isDragDown)
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
        // 如果大于等于20，说明结束那一瞬间，scrollView产生了较大位移，此时继续保持scrollView减速行为，不锁顶
        if isTopLockLatchedInCurrentGesture, scrollView.contentOffset.y < 20 {
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
        guard delegate?.sheetConfiguration.sheetDrivingMode.allowsPanDriving != false else { return }

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

        let velocity = gesture.velocity(in: gestureView)
        delegate.sheetInteraction(self, draggingEndedWithVelocity: velocity)
        hasRespondedPanInCurrentGesture = false
    }
}

// MARK: - Sheet Displacement

extension SheetInteraction {

    private func applyDisplacementToSheet(
        _ yDisplacement: CGFloat,
        velocity: CGPoint,
        source: DisplacementSource
    ) {
        let currentY = view?.frame.origin.y ?? 0
        var displacement = yDisplacement
        let dampingFactor = calculateDampingFactor(
            velocity: velocity,
            currentY: currentY,
        )
        displacement *= dampingFactor
        let newY = currentY + displacement

        let maxY = maximumSheetYPosition(for: source)
        let clampedY = max(newY, maxY)
        delegate?.sheetInteraction(self, didChangeOffset: clampedY)
    }

    /// 计算本帧允许的最小 Y（越小越靠上）。
    /// 当 expandsWhenScrolledToEdge 关闭时，上限固定在当前选中 detent。
    private func maximumSheetYPosition(for source: DisplacementSource) -> CGFloat {
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
            return largestDetentYPosition
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

        guard effectiveDelta < 0,
              let newSheetY = view?.frame.origin.y,
              newSheetY <= maximumSheetYPosition(for: .scrollViewPan) else { return }

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
    private func calculateDampingFactor(
        velocity: CGPoint,
        currentY: CGFloat,
    ) -> CGFloat {
        guard velocity.y > 0 else { return 1.0 }

        if delegate?.shouldApplyDownwardDampingAtSmallestDetent == true,
           currentY >= smallestDetentYPosition {
            let overflow = currentY - smallestDetentYPosition
            let strength: CGFloat = 0.05
            let minFactor: CGFloat = 0.18
            let factor = 1.0 / (1.0 + strength * overflow)
            return max(minFactor, factor)
        }

        return 1.0
    }
}

// MARK: - UIGestureRecognizerDelegate

extension SheetInteraction: UIGestureRecognizerDelegate {

    /// 是否接收触摸：自动检测 scrollView，重置手势状态。
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        guard gestureRecognizer === panGestureRecognizer else { return true }

        let detected = detectScrollView(for: touch)
        if detected !== currentTouchingScrollView {
            currentTouchingScrollView = detected
        }

        configureScrollStateForNewTouch(detectedScrollView: detected)

        return true
    }

    /// 手势开始判断：过滤接近水平的拖拽，触点在 scrollView 内时直接拒绝。
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer,
              gestureRecognizer === panGestureRecognizer
        else { return true }

        if delegate?.sheetConfiguration.sheetDrivingMode.allowsPanDriving == false {
            return false
        }

        if currentTouchingScrollView != nil {
            return false
        }

        let velocity = panGesture.velocity(in: panGesture.view)
        guard abs(velocity.y) > 0 else { return true }

        return abs(velocity.x) / abs(velocity.y) <= 2
    }
}

// MARK: - UIScrollView Helpers

private extension UIScrollView {

    /// 内容处于顶部时的 contentOffset.y（即 -contentInset.top）
    var topOffsetY: CGFloat { -contentInset.top }

    /// 将内容锁顶
    func lockToTop() {
        setContentOffset(CGPoint(x: contentOffset.x, y: topOffsetY), animated: false)
    }

    /// 判断 scrollView 的主轴是否为垂直滚动方向
    var isVerticalScrollDirection: Bool {
        if self is UITableView { return true }

        if let collectionView = self as? UICollectionView {
            if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                return flowLayout.scrollDirection == .vertical
            }
            if let compositionalLayout =
                collectionView.collectionViewLayout as? UICollectionViewCompositionalLayout {
                return compositionalLayout.configuration.scrollDirection == .vertical
            }
        }

        let verticalScrollable = contentSize.height > bounds.height
        let horizontalScrollable = contentSize.width > bounds.width

        if verticalScrollable && !horizontalScrollable { return true }
        if horizontalScrollable && !verticalScrollable { return false }

        return true
    }
}
