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

    /// 圆角半径
    var cornerRadius: CGFloat = 0 {
        didSet { updateAppliedCornerRadius() }
    }

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

    private func updateAppliedCornerRadius() {
        if #available(iOS 26, *) {
            applyModernCornerAppearance()
        } else {
            applyLegacyCornerAppearance()
        }
    }

    /// iOS 26：顶角 fixed，底角 containerConcentric。
    @available(iOS 26, *)
    private func makeCornerConfiguration() -> UICornerConfiguration {
        let top = UICornerRadius.fixed(cornerRadius)
        return .uniformTopRadius(top, bottomLeftRadius: .containerConcentric(), bottomRightRadius: .containerConcentric())
    }

    @available(iOS 26, *)
    private func applyModernCornerAppearance() {
        cornerConfiguration = makeCornerConfiguration()
        contentView.cornerConfiguration = .corners(radius: .containerConcentric())
        effectContainerView.cornerConfiguration = .corners(radius: .containerConcentric())
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
        let requested = max(0, cornerRadius)
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
