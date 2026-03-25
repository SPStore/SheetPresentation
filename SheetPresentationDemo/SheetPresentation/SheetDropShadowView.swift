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

    /// 将逻辑 `cornerRadius` 钳到当前 `contentView` 尺寸下可用的最大值并同步到 layer。
    private func updateAppliedCornerRadius() {
        contentView.layer.cornerRadius = effectiveCornerRadius(for: contentView.bounds)
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
