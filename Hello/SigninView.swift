//
//  SigninView.swift
//  Hello
//
//  Created by systec on 2019/7/15.
//  Copyright © 2019 systec. All rights reserved.
//

import UIKit

class SigninView: UIView {

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    
    required init?(coder aDecoder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
        super.init(coder: aDecoder)
        self.layer.contents = UIImage(named: "bg_qidong")?.cgImage
    }
    
}
