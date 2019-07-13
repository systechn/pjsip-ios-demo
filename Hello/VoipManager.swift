//
//  VoipManager.swift
//  Hello
//
//  Created by bluefish on 2019/7/13.
//  Copyright © 2019 systec. All rights reserved.
//

import UIKit

@objc class VoipManager: NSObject {
    
    static let queue = DispatchQueue(label: "com.systec.VoipManager", attributes: .concurrent)
    static var set = Set<NSObject>()
    
    @objc(sendMessage:data:) static func sendMessage(action: Int, data: String) {
        queue.sync {
            for item in set {
                let callback: VoipHandler = item as! VoipHandler
                callback.voipHandler(action: action, data: data)
            }
        }
    }
    
    @objc(addCallback:) static func addCallback(callback: NSObject) {
        queue.async(flags: .barrier) {
            VoipManager.set.insert(callback)
        }
    }
    
    @objc(removeCallback:) static func removeCallback(callback: NSObject) {
        queue.async(flags: .barrier) {
            VoipManager.set.remove(callback)
        }
    }
}
