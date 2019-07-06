//
//  ViewController.swift
//  Hello
//
//  Created by bluefish on 2019/7/5.
//  Copyright © 2019 systec. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var domain: UITextField!
    @IBOutlet weak var sipId: UITextField!
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var callee: UITextField!
    @IBOutlet weak var status: UILabel!
    @IBOutlet weak var info: UILabel!
    
    static var demo:ViewController? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        ViewController.demo = self
    }
    
    @objc(status:) static func status(data: String) {
        ViewController.demo?.status.text = data
    }
    
    @objc(info:) static func info(data: String) {
        ViewController.demo?.info.text = data
    }
    
    @IBAction func onRegister(_ sender: Any) {
        let domain = self.domain.text
        let sipId = self.sipId.text
        let password = self.password.text
        voip_add_account(domain, sipId, password)
    }
    
    @IBAction func onHangup(_ sender: Any) {
        voip_hangup()
    }
    
    @IBAction func onAnswer(_ sender: Any) {
        voip_answer()
    }
    
    @IBAction func onCall(_ sender: Any) {
        voip_call(callee.text)
    }
}

