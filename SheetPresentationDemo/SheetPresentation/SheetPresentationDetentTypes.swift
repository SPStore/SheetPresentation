//
//  SheetPresentationDetentTypes.swift
//  SheetPresentationDemo
//
//  Detent、Identifier 与解析上下文（从主控制器文件拆出以精简常用阅读路径）。
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
    /// 容器坐标系下，safe area 相对容器顶部的 inset（通常为 `containerView.safeAreaInsets.top`）。
    var containerSafeAreaTopInset: CGFloat { get }
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

        /// 内置 `large()` 顶边目标 Y（容器坐标）：随 safe area 变化，避免写死常量 pt。
        public static func preferredLargestDetentOriginY(safeAreaTop: CGFloat) -> CGFloat {
            max(safeAreaTop + largeDetentGapBelowSafeArea, 20)
        }

        /// 与 `large()` 顶边一致：相对容器 safe area 顶下沿的间距（pt）。
        public static let largeDetentGapBelowSafeArea: CGFloat = 0

        public static func medium() -> Detent {
            .custom(identifier: .medium) { $0.maximumDetentValue * 0.5 }
        }

        public static func large() -> Detent {
            .custom(identifier: .large) { ctx in
                let originY = preferredLargestDetentOriginY(safeAreaTop: ctx.containerSafeAreaTopInset)
                return max(0, ctx.maximumDetentValue - originY)
            }
        }

        @MainActor @preconcurrency
        public static func custom(
            identifier: SheetPresentationController.Detent.Identifier? = nil,
            resolver: @escaping (_ context: any SheetPresentationControllerDetentResolutionContext) -> CGFloat?
        ) -> SheetPresentationController.Detent {
            let id = identifier ?? .init("custom.\(UUID().uuidString)")
            return Detent(identifier: id, heightResolver: resolver)
        }

        @MainActor @preconcurrency
        public func resolvedValue(
            in context: any SheetPresentationControllerDetentResolutionContext
        ) -> CGFloat? {
            guard let raw = heightResolver?(context), raw.isFinite else { return nil }
            let cap = max(0, context.maximumDetentValue)
            return min(max(raw, 0), cap)
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
