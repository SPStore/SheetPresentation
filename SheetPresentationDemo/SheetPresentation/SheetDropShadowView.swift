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

    /// 圆角半径
    var cornerRadius: CGFloat = 0 {
        didSet { updateAppliedCornerRadius() }
    }

    /// 是否显示阴影
    var isShadowVisible: Bool = false {
        didSet { updateShadow() }
    }

    /// 是否启用 glass 视觉 + 按压动效（iOS 26+）
    @available(iOS 26, *)
    var isGlassEffectEnabled: Bool {
        get { _isGlassEffectEnabled }
        set {
            guard _isGlassEffectEnabled != newValue else { return }
            _isGlassEffectEnabled = newValue
            if newValue {
                let effect = UIGlassEffect(style: .regular)
                effect.isInteractive = true
                effectContainerView.effect = effect
                effectContainerView.cornerConfiguration = .corners(radius: .containerConcentric())
            } else {
                effectContainerView.effect = nil
            }
        }
    }
    private var _isGlassEffectEnabled: Bool = false

    /// 常驻容器：effect = nil 时退化为普通透明容器，iOS 26+ 启用 glass 时切换为 UIGlassEffect。
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
            cornerConfiguration = makeCornerConfiguration()
        } else {
            contentView.layer.cornerRadius = effectiveCornerRadius(for: contentView.bounds)
        }
    }

    /// iOS 26：顶角 fixed，底角 containerConcentric。
    @available(iOS 26, *)
    private func makeCornerConfiguration() -> UICornerConfiguration {
        let top = UICornerRadius.fixed(cornerRadius)
        return .uniformTopRadius(top, bottomLeftRadius: .containerConcentric(), bottomRightRadius: .containerConcentric())
    }

    /// pre-iOS 26：顶角不超过 min(半宽, 高)。
    private func effectiveCornerRadius(for bounds: CGRect) -> CGFloat {
        let requested = max(0, cornerRadius)
        guard requested > 0 else { return 0 }
        guard bounds.width > 0, bounds.height > 0,
              bounds.width.isFinite, bounds.height.isFinite else { return 0 }
        return min(requested, min(bounds.width * 0.5, bounds.height))
    }

    private func applyContentViewCornerMask() {
        if #available(iOS 26, *) {
            contentView.cornerConfiguration = .corners(radius: .containerConcentric())
        } else {
            contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
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
