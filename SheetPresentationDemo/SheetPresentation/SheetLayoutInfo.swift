//
//  SheetLayoutInfo.swift
//  SheetPresentationDemo
//
//  Created by 乐升平 on 2026/2/5.
//

import UIKit

/// 负责 sheet 的布局计算。
/// 管理 detent 值计算、Y 坐标映射、frame 生成等。
class SheetLayoutInfo: NSObject {

    // MARK: - 一级条目（detent entry）

    struct DetentEntry {
        let identifier: SheetPresentationController.Detent.Identifier
        let yPosition: CGFloat
        let height: CGFloat
    }

    enum LandingTarget {
        case detent(SheetPresentationController.Detent.Identifier)
        case dismiss
    }

    // MARK: - 输入属性（由 SheetPresentationController 设置）

    var containerBounds: CGRect = .zero {
        didSet { setNeedsInvalidation() }
    }

    var containerSafeAreaInsets: UIEdgeInsets = .zero

    var containerTraitCollection: UITraitCollection = .current

    var detents: [SheetPresentationController.Detent] = [] {
        didSet { invalidateDetents() }
    }

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

    // MARK: - 核心方法

    /// 重新计算所有 detent 的 Y 坐标和 height。
    func invalidateDetents() {
        guard !containerBounds.isEmpty else {
            sortedDetentEntries = []
            detentMap = [:]
            return
        }

        let context = ResolutionContext(
            containerTraitCollection: containerTraitCollection,
            maximumDetentValue: maximumDetentValue
        )

        var entries: [DetentEntry] = []
        for detent in detents {
            let rawHeight = detent.resolvedValue(in: context) ?? detent.height
            let height = min(max(rawHeight, 0), maximumDetentValue)
            let y = containerBounds.height - height
            entries.append(DetentEntry(identifier: detent.identifier, yPosition: y, height: height))
        }

        sortedDetentEntries = entries.sorted { $0.yPosition < $1.yPosition }
        detentMap = Dictionary(uniqueKeysWithValues: entries.map { ($0.identifier, $0) })
    }

    // MARK: - 查询方法

    /// 获取指定 detent 的 Y 坐标
    func yPosition(for identifier: SheetPresentationController.Detent.Identifier) -> CGFloat? {
        detentMap[identifier]?.yPosition
    }

    /// 根据 Y 坐标计算 presented view 的 frame
    func frameOfPresentedView(at yPosition: CGFloat) -> CGRect {
        // 最小高度限制为“最低 detent 对应的高度”，避免高度被压到 0 引发子约束告警。
        let minimumHeight = max(containerBounds.height - smallestDetentYPosition, 1)
        let height = max(containerBounds.height - yPosition, minimumHeight)
        return CGRect(x: 0, y: yPosition, width: containerBounds.width, height: height)
    }

    /// 根据 detent identifier 计算 frame
    func frameOfPresentedView(for identifier: SheetPresentationController.Detent.Identifier?) -> CGRect {
        guard let id = identifier, let y = yPosition(for: id) else {
            return frameOfPresentedView(at: largestDetentYPosition)
        }
        return frameOfPresentedView(at: y)
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

    // MARK: - Private

    private func setNeedsInvalidation() {
        guard !detents.isEmpty else { return }
        invalidateDetents()
    }

    // MARK: - 内部 Resolution Context

    private class ResolutionContext: NSObject, SheetPresentationControllerDetentResolutionContext {
        let containerTraitCollection: UITraitCollection
        let maximumDetentValue: CGFloat

        init(containerTraitCollection: UITraitCollection, maximumDetentValue: CGFloat) {
            self.containerTraitCollection = containerTraitCollection
            self.maximumDetentValue = maximumDetentValue
        }
    }
}
