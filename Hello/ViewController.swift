//
//  ViewController.swift
//  Hello
//
//  Created by bluefish on 2019/7/5.
//  Copyright © 2019 systec. All rights reserved.
//

import UIKit
import HandyJSON

class ViewController: UIViewController, VoipHandler, VideoPlayerHandler {

    @IBOutlet weak var domain: UITextField!
    @IBOutlet weak var sipId: UITextField!
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var callee: UITextField!
    @IBOutlet weak var status: UILabel!
    @IBOutlet weak var info: UILabel!
    @IBOutlet weak var videoUrl: UITextView!
    @IBOutlet weak var video: UIImageView!
    
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var videoStatus: UILabel!
    @IBOutlet weak var tcpClientData: UITextView!
    
    var videoPlaying:Bool = false
    
    var player:UnsafeMutableRawPointer? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        VoipManager.addCallback(callback: self)
        self.view.layer.contents = UIImage(named: "bg_qidong")?.cgImage
        self.view.layer.contentsGravity = CALayerContentsGravity.resizeAspectFill;
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        VoipManager.removeCallback(callback: self)
    }
    
    func voipHandler(action: Int, data: String) {
        if 0 == action {
            status.text = data
        } else if 1 == action {
            info.text = data
        }
    }
    
    func videoPlayerHandler(image: UIImage) {
        video.image = image
    }
    
    func videoPlayerMessageHandler(data: String) {
        videoStatus.text = data
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
        if(videoPlaying) {
            videoplayer_stop(player)
        }
        videoPlaying = true
        video.image = nil
        player = videoplayer_play(self, videoUrl.text)
    }
    
    @IBAction func onStop(_ sender: Any) {
        videoPlaying = false
        videoplayer_stop(player)
        video.image = nil
    }
    
    @IBAction func onTcpClient(_ sender: Any) {
        class Message: HandyJSON {
            required init() {}
            var code: Int!
            var message: String!
        }
        let queue = DispatchQueue(label: "com.systec.tcpclient")
        queue.async {
            let data: String = tcpclient_hello(
                "114.116.109.114",
                "/api/code",
                "{\"user_id\":\"0000000000000010\",\"server\":\"sg.systec-pbx.net\"}"
            );
            DispatchQueue.main.async {
//                NSLog("%@", data)
                let a_data = Message.deserialize(from: data)
                print(a_data!.code!, a_data!.message!)
                self.tcpClientData.text.append("\(data)\n")
                self.tcpClientData.scrollRangeToVisible(NSRange.init(location: self.tcpClientData.text.count, length: 1))
            }
        }
    }
}

