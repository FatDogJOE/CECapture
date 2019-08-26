//
//  StringUtility.swift
//  FDJUtility
//
//  Created by mac on 2019/7/25.
//

import Foundation
import CommonCrypto
import UIKit

public extension String {
    
    func md5() -> String {
        
        let cString = self.cString(using: .utf8)
        let strLen  = CUnsignedInt(self.lengthOfBytes(using: .utf8))
        let digestLen = Int(CC_MD5_DIGEST_LENGTH)
        let result = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: digestLen)
        CC_MD5(cString!, strLen, result)
        
        let hash = NSMutableString()
        
        for i in 0 ..< digestLen {
            hash.appendFormat("%02x", result[i])
        }
        
        result.deallocate()
        
        return String(format: hash as String)
    }
    
}

public extension NSAttributedString {
    
    convenience init(string:String, font:UIFont, color:UIColor) {
        self.init(string:string, attributes:[NSAttributedString.Key.font:font,NSAttributedString.Key.foregroundColor:color])
    }
    
}
