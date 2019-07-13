//
//  MessageHandler.swift
//  Hello
//
//  Created by bluefish on 2019/7/13.
//  Copyright © 2019 systec. All rights reserved.
//

import Foundation
import UIKit

@objc protocol VoipHandler {
    @objc(voipHandler:data:) func voipHandler(action: Int, data: String)
}

@objc protocol VideoPlayerHandler {
    @objc(videoPlayerHandler:) func videoPlayerHandler(image: UIImage)
    @objc(videoPlayerMessageHandler:) func videoPlayerMessageHandler(data: String)
}
