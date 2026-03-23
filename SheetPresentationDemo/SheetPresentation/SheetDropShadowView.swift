//
//  DropShadowView.swift
//  SheetPresentationDemo
//
//  Created by 乐升平 on 2026/2/6.
//

import UIKit

class SheetDropShadowView: UIButton {

    // MARK: - Properties

    /// 内容视图容器
    let contentView: UIView = {
        let view = UIView()
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
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

    /// 期望圆角半径（逻辑值）；实际绘制会按 `contentView` 尺寸钳制，避免大于半宽/半高或超过高度时出现畸形。
    var cornerRadius: CGFloat = 0 {
        didSet {
            updateAppliedCornerRadius()
        }
    }

    /// 是否显示阴影
    var isShadowVisible: Bool = false {
        didSet {
            updateShadow()
        }
    }

    /// 浮动样式时 contentView 四个角均为圆角；否则仅顶部两角。
    var contentViewRoundsAllCorners: Bool = false {
        didSet {
            applyContentViewCornerMask()
            updateAppliedCornerRadius()
        }
    }

    /// 是否启用 glass press 缩放效果（iOS 26+）。
    /// 开启后触摸 sheet 空白区域会触发 UIButton 的 _UISelectionInteraction 缩放动画。
    var isGlassEffectEnabled: Bool = false {
        didSet {
            guard oldValue != isGlassEffectEnabled else { return }
            if #available(iOS 26, *) {
                if isGlassEffectEnabled {
                    var config = UIButton.Configuration.glass()
                    config.cornerStyle = .fixed
                    configuration = config
                    // configuration 设置后才有意义，集中在此处理，不放入通用方法
                    changesSelectionAsPrimaryAction = false
                    configurationUpdateHandler = nil
                    toolTip = nil
                    updateAppliedCornerRadius()
                    applyUIViewLikeChromeBehavior()
                    // UIButton 内部会插入背景视图，确保 contentView/grabber 在其上方
                    bringSubviewToFront(contentView)
                    bringSubviewToFront(grabber)
                } else {
                    configuration = nil
                    applyUIViewLikeChromeBehavior()
                }
            }
        }
    }

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
        applyUIViewLikeChromeBehavior()

        gestureRecognizers?.forEach {
            removeGestureRecognizer($0)
        }

        contentView.frame = bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(contentView)

        grabber.isHidden = !isGrabberVisible
        addSubview(grabber)
        grabber.addTarget(self, action: #selector(grabberAction), for: .touchUpInside)

        applyContentViewCornerMask()
        updateShadow()
    }

    // MARK: - Actions

    @objc private func grabberAction() {
        grabberDidClickHandler?()
    }

    // MARK: - Layout

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01, isUserInteractionEnabled else { return nil }
        guard self.point(inside: point, with: event) else { return nil }

        // grabber 优先
        if isGrabberVisible,
           !grabber.isHidden,
           grabber.alpha > 0.01,
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

        if #available(iOS 26, *), isGlassEffectEnabled {
            bringSubviewToFront(contentView)
            bringSubviewToFront(grabber)
        }

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

    /// 将逻辑 `cornerRadius` 钳到当前 `contentView` 尺寸下可用的最大值，并同步到 layer 与 glass 背景。
    private func updateAppliedCornerRadius() {
        let applied = effectiveCornerRadius(for: contentView.bounds)
        contentView.layer.cornerRadius = applied
        if #available(iOS 26, *) {
            applyGlassBackgroundCornerRadius(applied)
        }
    }

    /// 几何上限：四角圆角时不超过半宽/半高；仅顶角时不超过 `min(半宽, 高)`。
    private func effectiveCornerRadius(for bounds: CGRect) -> CGFloat {
        let requested = max(0, cornerRadius)
        guard requested > 0 else { return 0 }
        guard bounds.width > 0, bounds.height > 0,
              bounds.width.isFinite, bounds.height.isFinite else { return 0 }
        let cap: CGFloat
        if contentViewRoundsAllCorners {
            cap = min(bounds.width, bounds.height) * 0.5
        } else {
            cap = min(bounds.width * 0.5, bounds.height)
        }
        return min(requested, cap)
    }

    @available(iOS 26, *)
    private func applyGlassBackgroundCornerRadius(_ applied: CGFloat) {
        guard isGlassEffectEnabled, var config = configuration else { return }
        config.background.cornerRadius = applied
        configuration = config
    }

    private func applyContentViewCornerMask() {
        if contentViewRoundsAllCorners {
            contentView.layer.maskedCorners = [
                .layerMinXMinYCorner, .layerMaxXMinYCorner,
                .layerMinXMaxYCorner, .layerMaxXMaxYCorner
            ]
        } else {
            contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }
    }

    /// 弱化 `UIControl` / `UIButton` 的默认交互与无障碍语义，使整块 chrome 更接近普通 `UIView` 容器（仅保留 iOS 26+ glass 所需能力）。
    private func applyUIViewLikeChromeBehavior() {
        isAccessibilityElement = false
        accessibilityTraits = []

        isExclusiveTouch = false
        isEnabled = true
        isSelected = false

        // 无 title/image，仅让内部 configuration 背景更易铺满 bounds（与 UIView「整区可布局」接近）。
        contentHorizontalAlignment = .fill
        contentVerticalAlignment = .fill

        tintAdjustmentMode = .normal
        contentView.tintAdjustmentMode = .normal

        isContextMenuInteractionEnabled = false
        if #available(iOS 13.4, *) {
            isPointerInteractionEnabled = false
        }
        if #available(iOS 14.0, *) {
            menu = nil
            showsMenuAsPrimaryAction = false
            role = .normal
        }
        if #available(iOS 17.0, *) {
            isSymbolAnimationEnabled = false
            hoverStyle = .none
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
