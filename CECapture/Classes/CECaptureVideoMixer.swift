//
//  CECaptureVideoMixer.swift
//  Alamofire
//
//  Created by mac on 2019/8/19.
//

import UIKit
import VideoToolbox

enum VideoMixerSessionError : Error {
    case initFailed
}

enum VideoMixerEncodeError : Error {
    case sessionInvailed
    case encodeFailed
}

func outputCallback(callbackRef:UnsafeMutableRawPointer?, sourceFrameRef:UnsafeMutableRawPointer?, status:OSStatus, infoFlags:VTEncodeInfoFlags, sampleBuffer:CMSampleBuffer?) -> Void {
    
    guard callbackRef != nil else {
        return
    }
    
    guard status == noErr else {
        return
    }
    
    guard sampleBuffer != nil else {
        return
    }
    
    let mixer = Unmanaged<CECaptureVideoMixer>.fromOpaque(callbackRef!).takeUnretainedValue()
    
    let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer!, false) as! Array<Any>
    
    let attachment = attachments.first as! [String:Any]
    
    let isKeyframe = (attachment[String(kCMSampleAttachmentKey_DependsOnOthers)] as! Bool == false)
    
    if isKeyframe {
        
        var spsPtr : UnsafePointer<UInt8>?
        var ppsPtr : UnsafePointer<UInt8>?
        
        var spsSize : Int = 0
        var ppsSize : Int = 0
        
        var spsCount : Int = 0
        var ppsCount : Int = 0
        
        var spsNALUHeaderLength : Int32 = 0
        var ppsNALUHeaderLehgth : Int32 = 0
        
        let format = CMSampleBufferGetFormatDescription(sampleBuffer!)
        
        let spsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format!,
                                                                           0,
                                                                           &spsPtr,
                                                                           &spsSize,
                                                                           &spsCount,
                                                                           &spsNALUHeaderLength)
        
        let ppsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format!,
                                                                           1,
                                                                           &ppsPtr,
                                                                           &ppsSize,
                                                                           &ppsCount,
                                                                           &ppsNALUHeaderLehgth)
        
        if spsStatus != noErr || ppsStatus != noErr {
            return
        }
        
        let spsBuffer = UnsafeBufferPointer<UInt8>(start: spsPtr, count: spsSize)
        let spsData = Data(buffer: spsBuffer)
        
        let ppsBuffer = UnsafeBufferPointer<UInt8>(start: ppsPtr, count: ppsSize)
        let ppsData = Data(buffer: ppsBuffer)
        
        mixer.write(pps: ppsData, sps: spsData)
    }
    
    let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer!)
    
    var length : Int = 0
    var totalLength : Int = 0
    var dataPtr : UnsafeMutablePointer<Int8>?
    
    let blockStatus = CMBlockBufferGetDataPointer(dataBuffer!,
                                                  0,
                                                  &length,
                                                  &totalLength,
                                                  &dataPtr)
    
    if blockStatus == noErr {
        
        let dataBufferPtr : UnsafeMutableBufferPointer<UInt8> = UnsafeMutableBufferPointer(start: nil, count: 0)
        
        var bufferOffset = 0
        
        let AVCCHeaderLength = 4
        
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            
            var NALUnitLength : UInt32 = 0
            
            // Read the NAL unit lengh
            
            
        }
        
    }
    

}

class CECaptureVideoMixer: NSObject {

    var width : Int32 = 0
    var height : Int32 = 0
    var fps : Int8 = 30
    var bitrate : Int = 2048 << 10
    var fileURL : URL?
    var fileHandle : FileHandle?
    
    var session : VTCompressionSession?
    
    func setupCompressionSession(width:Int32,height:Int32,fps:Int8,bitrate:Int, filePath:String) throws {
        
        self.width = width
        self.height = height
        self.fps = fps
        self.bitrate = bitrate << 10
        self.fileURL = URL(fileURLWithPath: filePath)
        
        try? FileManager.default.removeItem(at: self.fileURL!)
        FileManager.default.createFile(atPath: self.fileURL!.path, contents: nil, attributes: nil)
        
        do {
            self.fileHandle = try FileHandle(forWritingTo: self.fileURL!)
        } catch {
            throw error
        }
        
        let session : UnsafeMutablePointer<VTCompressionSession?> = UnsafeMutablePointer.allocate(capacity: 1)
        
        let status = VTCompressionSessionCreate(nil,
                                                self.width,
                                                self.height,
                                                kCMVideoCodecType_H264,
                                                nil,
                                                nil,
                                                nil,
                                                outputCallback,
                                                Unmanaged<CECaptureVideoMixer>.passRetained(self).toOpaque(),
                                                session)
        
        defer {
            session.deallocate()
        }
        
        if status != noErr {
            throw VideoMixerSessionError.initFailed
        }
        
        self.session = session.pointee
        
    }
    
    
    
    func startEncodeImages(images:[UIImage]) throws  {
        
        guard self.session != nil else {
            throw VideoMixerEncodeError.sessionInvailed
        }
        
        self.setupSessionProperties()
        
        for image in images {
            
            do {
                
                let sampleBuffer = try self.pixelBuffer(for: image.cgImage)
                
                let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
                let presentationTimestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                
                let encodeProperties = [kVTEncodeFrameOptionKey_ForceKeyFrame:true] as CFDictionary
                
                let status = VTCompressionSessionEncodeFrame(self.session!,
                                                             imageBuffer!,
                                                             presentationTimestamp,
                                                             kCMTimeInvalid,
                                                             encodeProperties,
                                                             nil,
                                                             nil)
                
                if status != noErr {
                    throw VideoMixerEncodeError.encodeFailed
                }
                
            } catch {
                
            }
            
        }
        
    }
    
    func write(pps pData:Data, sps sData:Data) {
        
        let NALHeader:[UInt8] = [0x00,0x00,0x00,0x01]
        
        let byteHeader = Data(bytes: NALHeader)
        
        self.fileHandle?.write(byteHeader)
        self.fileHandle?.write(sData)
        self.fileHandle?.write(byteHeader)
        self.fileHandle?.write(pData)
        
    }
    
    private func setupSessionProperties() {
        
        //设置关键帧间隔
        let iframeRef = CFNumberCreate(kCFAllocatorDefault, CFNumberType.intType, &self.fps)
        VTSessionSetProperty(self.session!, kVTCompressionPropertyKey_MaxKeyFrameInterval, iframeRef)
        
        //设置期望帧率
        let fpsRef = CFNumberCreate(kCFAllocatorDefault, CFNumberType.intType, &self.fps)
        VTSessionSetProperty(self.session!, kVTCompressionPropertyKey_ExpectedFrameRate, fpsRef)
        
        //设置码率
        var bigRate = self.width * self.height * 3 * 4 * 8
        let bigRateRef = CFNumberCreate(kCFAllocatorDefault, CFNumberType.sInt32Type, &bigRate)
        VTSessionSetProperty(self.session!, kVTCompressionPropertyKey_AverageBitRate, bigRateRef)
        
        var bigRateLimit = self.width * self.height * 3 * 4
        let bigRateLimitRef = CFNumberCreate(kCFAllocatorDefault, CFNumberType.sInt32Type, &bigRateLimit)
        VTSessionSetProperty(self.session!, kVTCompressionPropertyKey_DataRateLimits, bigRateLimitRef)
        
        //准备开始编码
        VTCompressionSessionPrepareToEncodeFrames(self.session!)
        
    }
    
    private func pixelBuffer(for image:CGImage?) throws -> CMSampleBuffer {
        
        guard image != nil else {
            throw PixelBufferError.imageIsNil
        }
        
        
        
        let options = [kCVPixelBufferCGImageCompatibilityKey:true,kCVPixelBufferCGBitmapContextCompatibilityKey:true] as CFDictionary
        
        let buffer : UnsafeMutablePointer<CVPixelBuffer?> = UnsafeMutablePointer<CVPixelBuffer?>.allocate(capacity: 1)
        
        CVPixelBufferCreate(kCFAllocatorDefault, image!.width, image!.height, kCVPixelFormatType_32ARGB, options, buffer)
        
        guard buffer.pointee != nil else {
            throw PixelBufferError.invalidPixcelBuffer
        }
        
        CVPixelBufferLockBaseAddress(buffer.pointee!, CVPixelBufferLockFlags.readOnly)
        
        let pxData = CVPixelBufferGetBaseAddress(buffer.pointee!)
        
        guard pxData != nil else {
            throw PixelBufferError.invalidPixcelBuffer
        }
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        let context = CGContext(data: pxData,
                                width: image!.width,
                                height: image!.height,
                                bitsPerComponent: image!.bitsPerComponent,
                                bytesPerRow: image!.bytesPerRow,
                                space: rgbColorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
        
        context?.draw(image!, in: CGRect(x: 0, y: 0, width: image!.width, height: image!.height))
        
        CVPixelBufferUnlockBaseAddress(buffer.pointee!, CVPixelBufferLockFlags.readOnly)
        
        
        let videoInfo : UnsafeMutablePointer<CMVideoFormatDescription?> = UnsafeMutablePointer.allocate(capacity: 1)
        
        CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, buffer.pointee!, videoInfo)
        
        let frameTime = CMTimeMake(1, 1)
        
        var timing = CMSampleTimingInfo(duration: frameTime, presentationTimeStamp: frameTime, decodeTimeStamp: kCMTimeInvalid)
        
        let sampleBuffer : UnsafeMutablePointer<CMSampleBuffer?> = UnsafeMutablePointer.allocate(capacity: 1)
        
        CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,
                                           buffer.pointee!,
                                           true,
                                           nil,
                                           nil,
                                           videoInfo.pointee!,
                                           &timing,
                                           sampleBuffer)
        
        defer {
            videoInfo.deallocate()
            buffer.deallocate()
            sampleBuffer.deallocate()
        }
        
        return sampleBuffer.pointee!
        
    }

}
