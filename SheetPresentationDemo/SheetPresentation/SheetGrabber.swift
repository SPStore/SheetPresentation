//
//  SheetGrabber.swift
//  SheetPresentationDemo
//
//  Created by 乐升平 on 2026/1/31.
//

import UIKit

class SheetGrabber: UIControl {

    private let contrastEffectView: UIVisualEffectView = {
        let effect: UIBlurEffect = UIBlurEffect(style: .systemMaterial)
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

    override func didMoveToWindow() {
        super.didMoveToWindow()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contrastEffectView.frame = bounds
        contrastEffectView.layer.cornerRadius = bounds.height * 0.5
        contrastEffectView.layer.masksToBounds = true
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // 扩大点击区域
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
        return CGSize(width: 36, height: 5)
    }
}
