//
//  SheetDimmingView.swift
//  SheetPresentationDemo
//
//  Created by 乐升平 on 2026/1/31.
//

import UIKit

open class SheetDimmingView: UIView {
    
    // MARK: - Properties

    /// 点击回调
    open var didTap: (() -> Void)?
    
    /// 背景透明度
    open var backgroundAlpha: CGFloat = 0.4 {
        didSet {
            backgroundColor = UIColor.black.withAlphaComponent(backgroundAlpha)
        }
    }
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(backgroundAlpha)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Actions
    
    @objc private func handleTap() {
        didTap?()
    }
}
