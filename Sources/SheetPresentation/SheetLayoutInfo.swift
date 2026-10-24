//
//  SheetLayoutInfo.swift
//  SheetPresentationDemo
//
//  Created by 乐升平 on 2026/2/5.
//

import UIKit

/// 负责 sheet 的布局计算。
/// 管理 detent 值计算、Y 坐标映射、frame 生成等。
@MainActor
class SheetLayoutInfo: NSObject {

    /// 现代 Sheet 的窗口边缘留白；底部是否留白由档位和浮动样式决定，不能一律叠加。
    nonisolated static let minimumEdgeInset: CGFloat = 8

    // MARK: - 一级条目（detent entry）

    struct DetentEntry {
        let identifier: SheetPresentationController.Detent.Identifier
        let yPosition: CGFloat
        let height: CGFloat
        let bottomInset: CGFloat
    }

    enum LandingTarget {
        case detent(SheetPresentationController.Detent.Identifier)
        case dismiss
    }

    // MARK: - 输入属性（由 SheetPresentationController 设置）

    var containerBounds: CGRect = .zero {
        didSet { invalidateDetents() }
    }

    var containerSafeAreaInsets: UIEdgeInsets = .zero {
        didSet { invalidateDetents() }
    }

    var containerTraitCollection: UITraitCollection = .current {
        didSet { invalidateDetents() }
    }

    var detents: [SheetPresentationController.Detent] = [] {
        didSet { invalidateDetents() }
    }

    /// 浮动样式参与档位落点计算；最终 frame、手势吸附和转场共用同一份几何。
    var prefersFloatingStyle: Bool = false {
        didSet { invalidateDetents() }
    }

    /// 跳过自适应限宽，保持容器全宽；不影响浮动样式自身的边距。
    var prefersFullWidth: Bool = false

    // MARK: - 计算属性

    /// 可用于 detent resolver 的最大值（容器高度）
    var maximumDetentValue: CGFloat {
        containerBounds.height
    }

    /// dismiss 位置 Y（容器底部）
    var dismissYPosition: CGFloat {
        containerBounds.height
    }

    /// 最大 detent（最靠近顶部、Y 值最小）的 Y 坐标
    var largestDetentYPosition: CGFloat {
        sortedDetentEntries.first?.yPosition ?? containerBounds.height
    }

    /// 最小 detent（最靠近底部、Y 值最大）的 Y 坐标
    var smallestDetentYPosition: CGFloat {
        sortedDetentEntries.last?.yPosition ?? containerBounds.height
    }

    // MARK: - 缓存数据

    /// 按 Y 升序排列的 detent 条目（height 最大的排在最前）
    private(set) var sortedDetentEntries: [DetentEntry] = []

    /// 以 identifier 为 key 的快速查找表
    private(set) var detentMap: [SheetPresentationController.Detent.Identifier: DetentEntry] = [:]

    /// `performBatchUpdates` 嵌套深度；>0 时 `invalidateDetents` 只打标，退出最外层时再算一次。
    private var batchUpdateDepth = 0
    private var pendingInvalidateDetents = false

    // MARK: - 批量更新（类似 `NSMutableAttributedString` begin/endEditing）

    /// 在闭包内连续改 `containerBounds` / `containerTraitCollection` / `containerSafeAreaInsets` / `detents` 等，结束时最多 **`invalidateDetents` 一次**。
    func performBatchUpdates(_ updates: () -> Void) {
        batchUpdateDepth += 1
        updates()
        batchUpdateDepth -= 1
        guard batchUpdateDepth == 0, pendingInvalidateDetents else { return }
        pendingInvalidateDetents = false
        invalidateDetents()
    }

    // MARK: - 核心方法

    /// 重新计算所有 detent 的 Y 坐标和 height。
    func invalidateDetents() {
        if batchUpdateDepth > 0 {
            pendingInvalidateDetents = true
            return
        }
        guard !detents.isEmpty else {
            sortedDetentEntries = []
            detentMap = [:]
            return
        }
        guard !containerBounds.isEmpty else {
            sortedDetentEntries = []
            detentMap = [:]
            return
        }

        let context = ResolutionContext(
            containerTraitCollection: containerTraitCollection,
            maximumDetentValue: maximumDetentValue,
            containerSafeAreaTopInset: containerSafeAreaInsets.top
        )

        var entries: [DetentEntry] = []
        for detent in detents {
            let rawHeight = detent.resolvedValue(in: context) ?? detent.height
            let height = min(max(rawHeight, 0), maximumDetentValue)
            let baseY = containerBounds.height - height
            let bottomInset = floatingInset(forRestingY: baseY)
            // resolver 返回的高度不被底部间距挤压，也不在展示时再次减掉间距。
            entries.append(DetentEntry(
                identifier: detent.identifier,
                yPosition: baseY - bottomInset,
                height: height,
                bottomInset: bottomInset
            ))
        }

        var seen = Set<SheetPresentationController.Detent.Identifier>()
        let uniqueEntries = entries.filter { seen.insert($0.identifier).inserted }
        sortedDetentEntries = uniqueEntries.sorted { $0.yPosition < $1.yPosition }
        detentMap = Dictionary(uniqueKeysWithValues: uniqueEntries.map { ($0.identifier, $0) })
    }

    // MARK: - 查询方法

    /// 获取指定 detent 的 Y 坐标
    func yPosition(for identifier: SheetPresentationController.Detent.Identifier) -> CGFloat? {
        detentMap[identifier]?.yPosition
    }

    /// 宽屏采用居中的页面比例，不让横向展开把 sheet 拉成横跨整个窗口的长条。
    /// 窗口没有顶部安全区时保留侧边留白；使用当前容器而非主屏尺寸，兼容折叠和分屏。
    private var resolvedWidth: CGFloat {
        guard !prefersFullWidth else { return containerBounds.width }
        let topInset = max(0, containerSafeAreaInsets.top)
        let edgeInset = resolvedEdgeInset
        let availableWidth = max(0, containerBounds.width - edgeInset * 2)
        guard containerTraitCollection.horizontalSizeClass == .regular else { return availableWidth }
        let maximumWidth = max(0, containerBounds.height - max(topInset, Self.minimumEdgeInset) * 2)
        return min(availableWidth, maximumWidth)
    }

    private var resolvedEdgeInset: CGFloat {
        guard !prefersFullWidth else { return 0 }
        let topInset = max(0, containerSafeAreaInsets.top)
        if #available(iOS 26, *) {
            return topInset < Self.minimumEdgeInset ? Self.minimumEdgeInset : 0
        }
        return containerTraitCollection.verticalSizeClass == .compact ? 0 : max(Self.minimumEdgeInset - topInset, 0)
    }

    /// 唯一的 frame 出口：限宽与浮动留白取更严格的约束，不在限宽之后再缩小一遍。
    func presentedFrame(at yPosition: CGFloat) -> CGRect {
        let bottomInset = floatingInset(at: yPosition)
        let availableWidth = max(0, containerBounds.width - bottomInset * 2)
        let width = min(resolvedWidth, availableWidth)
        // 关闭过程中保持最低档的最小高度，避免内容约束被临时压缩到 0。
        let minimumHeight = max(sortedDetentEntries.last?.height ?? 0, 1)
        let height = max(containerBounds.height - bottomInset - yPosition, minimumHeight)
        return CGRect(x: containerBounds.midX - width * 0.5, y: yPosition, width: width, height: height)
    }

    /// 根据 detent identifier 计算 frame
    func frameOfPresentedView(for identifier: SheetPresentationController.Detent.Identifier?) -> CGRect {
        guard let id = identifier, let y = yPosition(for: id) else {
            return presentedFrame(at: largestDetentYPosition)
        }
        return presentedFrame(at: y)
    }

    // MARK: - 浮动样式布局

    /// 系统对照中，部分高度档位使用 8pt 留白，最大展开档贴底；不会因面板更短而无限收窄。
    private func floatingInset(forRestingY yPosition: CGFloat) -> CGFloat {
        guard #available(iOS 26, *), prefersFloatingStyle else { return 0 }
        let topY = SheetPresentationController.Detent.preferredLargestDetentOriginY(
            safeAreaTop: containerSafeAreaInsets.top
        )
        // 接近最大高度时最多取剩余距离的一半，让相近自定义档位的落点仍严格递增，不越过 large。
        return min(Self.minimumEdgeInset, max(0, (yPosition - topY) * 0.5))
    }

    /// 在相邻档位的最终落点之间连续插值；越过最低档关闭时保持间距，不继续缩窄。
    private func floatingInset(at yPosition: CGFloat) -> CGFloat {
        guard prefersFloatingStyle,
              let first = sortedDetentEntries.first,
              let last = sortedDetentEntries.last else { return 0 }
        if yPosition <= first.yPosition { return first.bottomInset }
        if yPosition >= last.yPosition { return last.bottomInset }
        for (upper, lower) in zip(sortedDetentEntries, sortedDetentEntries.dropFirst()) {
            guard yPosition <= lower.yPosition else { continue }
            let distance = lower.yPosition - upper.yPosition
            guard distance > 0 else { return lower.bottomInset }
            let progress = (yPosition - upper.yPosition) / distance
            return upper.bottomInset + (lower.bottomInset - upper.bottomInset) * progress
        }
        return last.bottomInset
    }

    /// 获取指定 detent 条目。
    func entry(for identifier: SheetPresentationController.Detent.Identifier) -> DetentEntry? {
        detentMap[identifier]
    }

    /// 获取相对指定 detent 偏移后的条目（offset: -1 上一档, +1 下一档）。
    func relativeEntry(
        from identifier: SheetPresentationController.Detent.Identifier,
        offset: Int
    ) -> DetentEntry? {
        guard let index = sortedDetentEntries.firstIndex(where: { $0.identifier == identifier }) else {
            return nil
        }
        let targetIndex = index + offset
        guard sortedDetentEntries.indices.contains(targetIndex) else {
            return nil
        }
        return sortedDetentEntries[targetIndex]
    }

    /// 计算最近落点（detent 或 dismiss）。
    func nearestLandingTarget(to yPosition: CGFloat, allowsDismiss: Bool) -> LandingTarget? {
        let nearestDetent = sortedDetentEntries.min {
            abs($0.yPosition - yPosition) < abs($1.yPosition - yPosition)
        }
        guard let nearestDetent else {
            return allowsDismiss ? .dismiss : nil
        }

        guard allowsDismiss else {
            return .detent(nearestDetent.identifier)
        }

        let dismissDistance = abs(dismissYPosition - yPosition)
        let detentDistance = abs(nearestDetent.yPosition - yPosition)
        if dismissDistance < detentDistance {
            return .dismiss
        }
        return .detent(nearestDetent.identifier)
    }

    /// 计算 dimming 进度。当 sheet 从最小 detent 向 dismiss 方向移动时渐变。
    /// 返回 0 → 完全不透明，1 → 完全透明。
    func dimmingProgress(at yPosition: CGFloat) -> CGFloat {
        let range = dismissYPosition - smallestDetentYPosition
        guard range > 0 else { return 0 }
        let progress = (yPosition - smallestDetentYPosition) / range
        return min(max(progress, 0), 1)
    }

    // MARK: - 内部 Resolution Context

    private class ResolutionContext: NSObject, SheetPresentationControllerDetentResolutionContext {
        let containerTraitCollection: UITraitCollection
        let maximumDetentValue: CGFloat
        let containerSafeAreaTopInset: CGFloat

        init(
            containerTraitCollection: UITraitCollection,
            maximumDetentValue: CGFloat,
            containerSafeAreaTopInset: CGFloat
        ) {
            self.containerTraitCollection = containerTraitCollection
            self.maximumDetentValue = maximumDetentValue
            self.containerSafeAreaTopInset = containerSafeAreaTopInset
        }
    }
}
