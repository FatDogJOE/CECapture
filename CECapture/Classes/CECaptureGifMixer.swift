//
//  CECaptureGifMixer.swift
//  Alamofire
//
//  Created by mac on 2019/8/26.
//

import UIKit
import MobileCoreServices

class CECaptureGifMixer: NSObject {
    
    func createGif(with images:[UIImage]) -> Data {
        
        let imageData = NSMutableData()
        
        let destion = CGImageDestinationCreateWithData(imageData, kUTTypeGIF, images.count, nil)
        
        let frameInfo = [kCGImagePropertyGIFDelayTime:5]
        
        let gifParamDic = [kCGImagePropertyGIFHasGlobalColorMap:true,kCGImagePropertyColorModel:kCGImagePropertyColorModelRGB,kCGImagePropertyDepth:8,kCGImagePropertyGIFLoopCount:1] as [CFString : Any]
        
        for image in images {
            CGImageDestinationAddImage(destion!, image.cgImage!, frameInfo as CFDictionary)
        }
        
        CGImageDestinationSetProperties(destion!, gifParamDic as CFDictionary)
        CGImageDestinationFinalize(destion!)
        
        return imageData as Data
    }

}
