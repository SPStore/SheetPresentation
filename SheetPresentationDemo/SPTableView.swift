//
//  SPTableView.swift
//  SheetPresentationDemo
//
//  Created by 乐升平 on 2026/3/6.
//

import UIKit

class SPTableView: UITableView {

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    
//    override func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
//        super.setContentOffset(contentOffset, animated: animated)
//        
//        print("contentOffset: \(contentOffset.y)")
//    }

    override var frame: CGRect {
        didSet {
            print("frame.h: \(frame.height)")
        }
    }
}
