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
    @IBOutlet weak var videoUrl: UITextView!
    @IBOutlet weak var video: UIImageView!
    
    static var demo:ViewController? = nil
    
    static var videoPlaying:Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        ViewController.demo = self
    }
    
    func createImage(color: UIColor, size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let path = UIBezierPath.init(rect: CGRect.init(x: 0, y: 0, width: size.width, height: size.height))
        color.setFill()
        path.fill()
        let image: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
    
    @objc(status:) static func status(data: String) {
        ViewController.demo?.status.text = data
    }
    
    @objc(info:) static func info(data: String) {
        ViewController.demo?.info.text = data
    }
    
    @objc(image:) static func image(data: UIImage) {
        if(!ViewController.videoPlaying) {
            ViewController.demo?.video.image = nil
            return
        }
        ViewController.demo?.video.image = data
    }
    
    @IBAction func onRegister(_ sender: Any) {
        let domain = self.domain.text
        let sipId = self.sipId.text
        let password = self.password.text
        voip_account_update(domain, sipId, password)
    }
    
    @IBAction func onUnregister(_ sender: Any) {
        voip_account_unregister()
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
    
    @IBAction func onPlay(_ sender: Any) {
        ViewController.videoPlaying = true
        ViewController.demo?.video.image = nil
        videoplayer_play(videoUrl.text)
    }
    
    @IBAction func onStop(_ sender: Any) {
        ViewController.videoPlaying = false
        videoplayer_stop()
        ViewController.demo?.video.image = nil
    }
}

