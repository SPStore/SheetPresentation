//
//  DropShadowView.swift
//  SheetPresentationDemo
//
//  Created by 乐升平 on 2026/2/6.
//

import UIKit

class SheetDropShadowView: UIView {

    // MARK: - Properties

    /// 内容视图容器
    let contentView: UIView = {
        let view = UIView()
        view.layer.masksToBounds = true
        return view
    }()

    /// 顶部手柄
    private let grabber = SheetGrabber()

    /// 手柄点击回调
    var grabberDidClickHandler: (() -> Void)?

    /// 是否显示手柄
    var isGrabberVisible: Bool = false {
        didSet {
            grabber.isHidden = !isGrabberVisible
            setNeedsLayout()
        }
    }

    /// nil 根据窗口几何选择同心或独立面板样式；显式值优先，0 明确表示直角。
    var cornerRadius: CGFloat? {
        didSet { updateAppliedCornerRadius() }
    }

    /// 当前档位的停靠 frame，使用父视图坐标系；由展示控制器维护，不包含手势和转场的临时位移。
    var automaticCornerReferenceFrame: CGRect?

    /// 自动样式中，宽布局或有侧边留白且实际贴底的面板底部使用直角；显式 cornerRadius 不受此规则影响。
    var usesSquareAutomaticBottomCorners = false

    /// 独立面板的设计值，不是同心半径的下限，也不是 UIKit 的通用默认值。
    private static let standaloneCornerRadius: CGFloat = 40

    /// 自定义转场容器可能丢失窗口圆角上下文，参考容器直接挂到窗口，且不参与显示或交互。
    private let windowCornerReferenceView: UIView = {
        let view = UIView()
        view.isHidden = true
        view.isUserInteractionEnabled = false
        view.accessibilityElementsHidden = true
        return view
    }()

    /// 与弹窗在窗口中的位置一致，让 UIKit 负责解析各个角的同心半径。
    private let concentricReferenceView = UIView()

    /// 是否显示阴影
    var isShadowVisible: Bool = false {
        didSet { updateShadow() }
    }

    /// 背景视觉效果，nil 时背景完全透明。
    var backgroundEffect: UIVisualEffect? {
        didSet {
            updateEffectStyle()
            nudgeFrameForGlassEffectRefreshIfNeeded()
        }
    }

    /// 常驻容器：默认提供模糊效果，iOS 26+ 优先使用 glass，低版本使用 `.light`。
    private let effectContainerView = UIVisualEffectView(effect: nil)

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        effectContainerView.frame = bounds
        effectContainerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(effectContainerView)

        let inner = effectContainerView.contentView
        contentView.frame = inner.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        inner.addSubview(contentView)

        grabber.isHidden = !isGrabberVisible
        grabber.addTarget(self, action: #selector(grabberAction), for: .touchUpInside)
        inner.addSubview(grabber)

        updateAppliedCornerRadius()
        updateEffectStyle()
        updateShadow()
    }

    // MARK: - Actions

    @objc private func grabberAction() {
        grabberDidClickHandler?()
    }

    // MARK: - Layout

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01, isUserInteractionEnabled else { return nil }

        // grabber 优先
        if isGrabberVisible,
           !grabber.isHidden,
           grabber.isUserInteractionEnabled {
            let pointInGrabber = grabber.convert(point, from: self)
            if grabber.point(inside: pointInGrabber, with: event) {
                return grabber.hitTest(pointInGrabber, with: event) ?? grabber
            }
        }
        return super.hitTest(point, with: event)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if isGrabberVisible {
            let grabberSize = grabber.intrinsicContentSize
            grabber.frame = CGRect(
                x: (bounds.width - grabberSize.width) * 0.5,
                y: 5,
                width: grabberSize.width,
                height: grabberSize.height
            )
            grabber.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin]
        }
        updateAppliedCornerRadius()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            windowCornerReferenceView.removeFromSuperview()
        }
        updateAppliedCornerRadius()
    }

    /// 使用停靠布局同步圆角，拖拽位移本身不切换贴边与独立面板样式。
    func updateAppliedCornerRadius() {
        if #available(iOS 26, *) {
            applyModernCornerAppearance()
        } else {
            applyLegacyCornerAppearance()
        }
    }

    /// 自动模式逐角选择场景，保留折叠屏左右设备角的差异，不用最小半径掩盖合法的直角。
    @available(iOS 26, *)
    private func makeCornerConfiguration() -> UICornerConfiguration {
        if let cornerRadius {
            windowCornerReferenceView.removeFromSuperview()
            return .corners(radius: .fixed(max(0, cornerRadius)))
        }
        guard let window else {
            windowCornerReferenceView.removeFromSuperview()
            return .corners(radius: .fixed(Self.standaloneCornerRadius))
        }

        if windowCornerReferenceView.superview !== window {
            window.insertSubview(windowCornerReferenceView, at: 0)
        }
        windowCornerReferenceView.frame = window.bounds
        windowCornerReferenceView.cornerConfiguration = .corners(radius: .containerConcentric())
        if concentricReferenceView.superview !== windowCornerReferenceView {
            windowCornerReferenceView.addSubview(concentricReferenceView)
        }
        let rect: CGRect
        if let automaticCornerReferenceFrame, let superview {
            rect = superview.convert(automaticCornerReferenceFrame, to: windowCornerReferenceView)
        } else {
            rect = convert(bounds, to: windowCornerReferenceView)
        }
        concentricReferenceView.frame = rect
        concentricReferenceView.cornerConfiguration = .corners(radius: .containerConcentric())
        windowCornerReferenceView.layoutIfNeeded()

        // 贴边范围由窗口的整体圆角几何决定，不能被非对称设备的某个小角缩短。
        let cornerRange = [UIRectCorner.topLeft, .topRight, .bottomLeft, .bottomRight]
            .map { windowCornerReferenceView.effectiveRadius(corner: $0) }
            .max() ?? 0
        let bottomLeft = usesSquareAutomaticBottomCorners ? 0
            : automaticRadius(for: .bottomLeft, rect: rect, cornerRange: cornerRange)
        let bottomRight = usesSquareAutomaticBottomCorners ? 0
            : automaticRadius(for: .bottomRight, rect: rect, cornerRange: cornerRange)

        return .corners(
            topLeftRadius: .fixed(automaticRadius(for: .topLeft, rect: rect, cornerRange: cornerRange)),
            topRightRadius: .fixed(automaticRadius(for: .topRight, rect: rect, cornerRange: cornerRange)),
            bottomLeftRadius: .fixed(bottomLeft),
            bottomRightRadius: .fixed(bottomRight)
        )
    }

    /// 角仍位于设备圆角范围内时使用 UIKit 的同心结果，否则切换为独立面板的设计圆角。
    @available(iOS 26, *)
    private func automaticRadius(for corner: UIRectCorner, rect: CGRect, cornerRange: CGFloat) -> CGFloat {
        let outerRadius = windowCornerReferenceView.effectiveRadius(corner: corner)
        let referenceBounds = windowCornerReferenceView.bounds
        let isLeading = corner == .topLeft || corner == .bottomLeft
        let isTop = corner == .topLeft || corner == .topRight
        let horizontalInset = isLeading ? rect.minX - referenceBounds.minX : referenceBounds.maxX - rect.maxX
        let verticalInset = isTop ? rect.minY - referenceBounds.minY : referenceBounds.maxY - rect.maxY
        let tolerance = 1 / max(1, traitCollection.displayScale)
        // 到达窗口圆角范围的边界后视为独立面板；设备的小角不单独触发该切换。
        let isNearCorner = horizontalInset >= -tolerance && verticalInset >= -tolerance
            && horizontalInset < cornerRange - tolerance && verticalInset < cornerRange - tolerance
        guard isNearCorner else { return Self.standaloneCornerRadius }
        let radius = concentricReferenceView.effectiveRadius(corner: corner)
        // 非对称设备的小角可能被面板边距完全抵消。贴边时保留该设备角，既不变直角，也不补成 40pt。
        if radius == 0, outerRadius < cornerRange { return outerRadius }
        return radius
    }

    @available(iOS 26, *)
    private func applyModernCornerAppearance() {
        let configuration = makeCornerConfiguration()
        cornerConfiguration = configuration
        contentView.cornerConfiguration = configuration
        effectContainerView.cornerConfiguration = configuration
    }

    private func applyLegacyCornerAppearance() {
        let radius = effectiveCornerRadius(for: contentView.bounds)
        let maskedCorners: CACornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        contentView.layer.cornerRadius = radius
        contentView.layer.maskedCorners = maskedCorners
        contentView.layer.masksToBounds = true

        effectContainerView.layer.cornerRadius = radius
        effectContainerView.layer.maskedCorners = maskedCorners
        effectContainerView.layer.masksToBounds = true
    }

    /// pre-iOS 26：顶角不超过 min(半宽, 高)。
    private func effectiveCornerRadius(for bounds: CGRect) -> CGFloat {
        let requested = max(0, cornerRadius ?? 13)
        guard requested > 0 else { return 0 }
        guard bounds.width > 0, bounds.height > 0,
              bounds.width.isFinite, bounds.height.isFinite else { return 0 }
        return min(requested, min(bounds.width * 0.5, bounds.height))
    }

    private func updateEffectStyle() {
        effectContainerView.effect = backgroundEffect
    }

    // 这个做一个frame微调整然后再还原，目的是触发effectContainerView重新应用effect，
    // 这应该是属于 iOS26 系统的bug，如果不做这一步，运行时修改effect不会生效.
    private func nudgeFrameForGlassEffectRefreshIfNeeded() {
        guard window != nil else { return }

        let originalFrame = frame
        let delta = 1.0 / UIScreen.main.scale

        UIView.performWithoutAnimation {
            frame = originalFrame.insetBy(dx: 0, dy: -delta)
            frame = originalFrame
        }
    }

    private func updateShadow() {
        if isShadowVisible {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOffset = CGSize(width: 0, height: -2)
            layer.shadowRadius = 10
            layer.shadowOpacity = 0.18
            layer.masksToBounds = false
        } else {
            layer.shadowColor = nil
            layer.shadowOffset = .zero
            layer.shadowRadius = 0
            layer.shadowOpacity = 0
        }
    }
}

// MARK: - Grabber

private final class SheetGrabber: UIControl {

    private let contrastEffectView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .systemMaterial)
        let view = UIVisualEffectView(effect: effect)
        view.isUserInteractionEnabled = false
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        backgroundColor = nil
        layer.cornerRadius = 2.5
        layer.masksToBounds = false

        addSubview(contrastEffectView)
        contrastEffectView.contentView.backgroundColor = .tertiaryLabel
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contrastEffectView.frame = bounds
        contrastEffectView.layer.cornerRadius = bounds.height * 0.5
        contrastEffectView.layer.masksToBounds = true
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let enlargedRect = bounds.insetBy(dx: -10, dy: -20)
        return enlargedRect.contains(point)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01, isUserInteractionEnabled,
              self.point(inside: point, with: event) else {
            return nil
        }
        return super.hitTest(point, with: event) ?? self
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: 36, height: 5)
    }
}
