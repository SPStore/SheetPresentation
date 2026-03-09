//
//  DropShadowView.swift
//  SheetPresentationDemo
//
//  Created by 乐升平 on 2026/2/6.
//

import UIKit

class DropShadowView: UIView {
    
    // MARK: - Properties
    
    /// 内容视图容器（带圆角和背景色）
    let contentView: UIView = {
        let view = UIView()
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.masksToBounds = true
        return view
    }()
    
    /// 顶部抓取条
    private let grabber = SheetGrabber()
    
    /// 抓取条点击回调
    var grabberDidClickHandler: (() -> Void)?
    
    /// 是否显示抓取条
    var isGrabberVisible: Bool = false {
        didSet {
            grabber.isHidden = !isGrabberVisible
            setNeedsLayout()
        }
    }
    
    /// 圆角半径
    var cornerRadius: CGFloat = 0 {
        didSet {
            contentView.layer.cornerRadius = cornerRadius
        }
    }
    
    /// 是否显示阴影
    var isShadowVisible: Bool = false {
        didSet {
            updateShadow()
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

        // 添加contentView
        contentView.frame = bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(contentView)
        
        // 设置抓取条（在contentView上面）
        grabber.isHidden = !isGrabberVisible
        addSubview(grabber)
        grabber.addTarget(self, action: #selector(grabberAction), for: .touchUpInside)
        
        // 初始化阴影
        updateShadow()
    }
    
    // MARK: - Actions
    
    @objc private func grabberAction() {
        grabberDidClickHandler?()
    }
    
    // MARK: - Layout

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01, isUserInteractionEnabled else {
            return nil
        }

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
        
        // 更新抓取条位置
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
    }

    // MARK: - Updates
    
    private func updateShadow() {
        if isShadowVisible {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowRadius = 10.0
            layer.shadowOffset = .zero
            layer.shadowOpacity = 0.2
        } else {
            layer.shadowColor = nil
            layer.shadowRadius = 0
            layer.shadowOffset = .zero
            layer.shadowOpacity = 0
        }
    }
}
