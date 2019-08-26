//
//  CECapture.swift
//  Aspects
//
//  Created by mac on 2019/8/15.
//

import UIKit

public class CECapture: NSObject {
    
    @objc public class func setup() {
        CECaptureEvent.share.setup()
        CECaptureMix.share.setup()
        CECaptureUploader.share.setup()
    }
    
    
}
