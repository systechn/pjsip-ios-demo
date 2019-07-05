//
//  ViewController.swift
//  Hello
//
//  Created by bluefish on 2019/7/5.
//  Copyright © 2019 systec. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var name: UILabel!
    
    static var demo:ViewController? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        ViewController.demo = self
    }
    
    @objc(name:dir:) static func name(path: String, dir: String) -> Int8 {
//        print(path, dir)
        ViewController.demo?.name.text = path
        return 0
    }
    
    @IBAction func onClick(_ sender: Any) {
        print(sender)
        self.name.text = "hehe"
    }
    
}

