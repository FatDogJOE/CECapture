//
//  CECaptureVideoMixer.swift
//  Alamofire
//
//  Created by mac on 2019/8/19.
//

import UIKit
import VideoToolbox
import RxSwift

enum VideoMixerSessionError : Error {
    case initFailed
}

enum VideoMixerEncodeError : Error {
    case sessionInvailed
    case encodeFailed
}

enum PixelBufferError : Error {
    case imageIsNil
    case invalidPixcelBuffer
}


enum VideoMixerTaskStatus {
    case waiting
    case ready
    case encoding
    case end
}

typealias VideoMixerTaskStatusHandler = ((CECaptureVideoMixTask)->(Void))

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
    
    let task = Unmanaged<CECaptureVideoMixTask>.fromOpaque(callbackRef!).takeUnretainedValue()
    
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
        
        task.write(pps: ppsData, sps: spsData)
        
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
        
        var bufferOffset : size_t = 0
        
        let AVCCHeaderLength : size_t = 4
        
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            
            var NALUnitLength : UInt32 = 0
            
            // Read the NAL unit lengh
            memcpy(&NALUnitLength, dataPtr! + bufferOffset, AVCCHeaderLength)
            
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength)
            
            let naluPtr = UnsafeRawPointer(dataPtr! + AVCCHeaderLength + bufferOffset)
            
            let naluData = Data(bytes: naluPtr, count: Int(NALUnitLength))
            
            task.write(encoded: naluData)
            
            bufferOffset += AVCCHeaderLength + size_t(NALUnitLength)
            
        }
        
    }
    
}

class CECaptureVideoMixTask : NSObject {
    
    var width : Int32 = 0
    var height : Int32 = 0
    var fps : Int8 = 30
    var fileURL : URL?
    var fileHandle : FileHandle?
    
    var status : VideoMixerTaskStatus = .waiting {
        didSet {
            self.statusHandler?(self)
        }
    }
    
    
    var session : VTCompressionSession?
    var images : [UIImage] = []
    
    fileprivate var statusHandler : VideoMixerTaskStatusHandler?
    
    func setupCompressionSession(width:Int32,height:Int32,fps:Int8, images:[UIImage], filePath:String) throws {
        
        self.width = width
        self.height = height
        self.fps = fps
        self.images = images
        self.fileURL = URL(fileURLWithPath: filePath)
        
        try? FileManager.default.removeItem(at: self.fileURL!)
        FileManager.default.createFile(atPath: self.fileURL!.path, contents: nil, attributes: nil)
        
        do {
            self.fileHandle = try FileHandle(forWritingTo: self.fileURL!)
        } catch {
            self.status = .end
            throw error
        }
        
        var session :VTCompressionSession?
        
        let status = VTCompressionSessionCreate(nil,
                                                self.width,
                                                self.height,
                                                kCMVideoCodecType_H264,
                                                nil,
                                                nil,
                                                nil,
                                                outputCallback,
                                                Unmanaged<CECaptureVideoMixTask>.passRetained(self).toOpaque(),
                                                &session)
        
        
        if status != noErr {
            self.status = .end
            throw VideoMixerSessionError.initFailed
        }
        
        self.session = session
        self.status = .ready
    }
    
    
    func startEncode() throws  {
        
        guard self.session != nil else {
            self.status = .end
            throw VideoMixerEncodeError.sessionInvailed
        }
        
        
        self.status = .encoding
        self.setupSessionProperties()
        
        for (index,image) in self.images.enumerated() {
            
            do {
                
                let sampleBuffer = try self.pixelBuffer(for: image.cgImage, index: index)
                
                let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
                
                for i in 1 ... self.fps {
                    
                    let unit : Int64 = 600 / Int64(self.fps)
                    
                    let presentationTimestamp = CMTimeMake(600 * Int64(index) + Int64(i) * unit , 600)
                    
                    let status = VTCompressionSessionEncodeFrame(self.session!,
                                                                 imageBuffer!,
                                                                 presentationTimestamp,
                                                                 kCMTimeInvalid,
                                                                 nil,
                                                                 nil,
                                                                 nil)
                    
                    
                    if status != noErr {
                        self.status = .end
                        throw VideoMixerEncodeError.encodeFailed
                    }
                    
                }
                
            } catch {
                self.status = .end
                throw error
            }
            
        }
        
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 1) {
            self.stopEncode()
        }
        
    }
    
    func stopEncode() {
        VTCompressionSessionCompleteFrames(self.session!, kCMTimeInvalid)
        VTCompressionSessionInvalidate(self.session!)
        self.fileHandle?.closeFile()
        self.fileHandle = nil
        self.status = .end
    }
    
    func write(encoded data:Data) {
        
        let startCode:[UInt8] = [0x00,0x00,0x00,0x01]
        
        let byteHeader = Data(bytes: startCode)
        
        self.fileHandle?.write(byteHeader)
        self.fileHandle?.write(data)
    }
    
    func write(pps pData:Data, sps sData:Data) {
        
        let startCode:[UInt8] = [0x00,0x00,0x00,0x01]
        
        let byteHeader = Data(bytes: startCode)
        
        self.fileHandle?.write(byteHeader)
        self.fileHandle?.write(sData)
        self.fileHandle?.write(byteHeader)
        self.fileHandle?.write(pData)
        
    }
    
    private func setupSessionProperties() {
        
        //设置关键帧间隔
        VTSessionSetProperty(self.session!, kVTCompressionPropertyKey_MaxKeyFrameInterval, self.fps as CFNumber)
        
        //设置期望帧率
        VTSessionSetProperty(self.session!, kVTCompressionPropertyKey_ExpectedFrameRate, self.fps as CFNumber)
        
        //关键帧持续时间
        VTSessionSetProperty(self.session!, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, 1 as CFNumber)
        
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
    
    private func pixelBuffer(for image:CGImage?, index:Int) throws -> CMSampleBuffer {
        
        guard image != nil else {
            throw PixelBufferError.imageIsNil
        }
        
        let options = [kCVPixelBufferCGImageCompatibilityKey:true,kCVPixelBufferCGBitmapContextCompatibilityKey:true] as CFDictionary
        
        var buffer : CVPixelBuffer?
        
        CVPixelBufferCreate(kCFAllocatorDefault, image!.width, image!.height, kCVPixelFormatType_32ARGB, options, &buffer)
        
        guard buffer != nil else {
            throw PixelBufferError.invalidPixcelBuffer
        }
        
        CVPixelBufferLockBaseAddress(buffer!, CVPixelBufferLockFlags.readOnly)
        
        let pxData = CVPixelBufferGetBaseAddress(buffer!)
        
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
        
        CVPixelBufferUnlockBaseAddress(buffer!, CVPixelBufferLockFlags.readOnly)
        
        var videoInfo : CMVideoFormatDescription?
        
        CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, buffer!, &videoInfo)
        
        var timing = CMSampleTimingInfo(duration: kCMTimeInvalid, presentationTimeStamp: kCMTimeInvalid, decodeTimeStamp: kCMTimeInvalid)
        
        var sampleBuffer : CMSampleBuffer?
        
        CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,
                                           buffer!,
                                           true,
                                           nil,
                                           nil,
                                           videoInfo!,
                                           &timing,
                                           &sampleBuffer)
        
        
        return sampleBuffer!
        
    }
    
}

protocol CECaptureVideoDelegate : NSObject {
    
    func mixer(mixer:CECaptureVideoMixer,didFinishTask task:CECaptureVideoMixTask) -> Void
    
}

class CECaptureVideoMixer: NSObject {
    
    var tasks : [CECaptureVideoMixTask] = []
    
    weak var delegate : CECaptureVideoDelegate?
    
    func startTask(with images:[UIImage], desPath:String) throws -> CECaptureVideoMixTask? {
        
        guard images.count > 0 else {
            return nil
        }
        
        let img = images.first!
        
        let task = CECaptureVideoMixTask()
        
        do {
            try task.setupCompressionSession(width: Int32(img.size.width),
                                                                height: Int32(img.size.height),
                                                                fps: 25,
                                                                images: images,
                                                                filePath: desPath)
            
            task.statusHandler = { [weak self] (encoder) in
                
                if encoder.status == .end {
                    
                    if let weakSelf = self {
                        weakSelf.delegate?.mixer(mixer: weakSelf, didFinishTask: encoder)
                        weakSelf.nextTask()
                    }
                    
                }
                
            }
            
        } catch {
            throw error
        }
        
        let shouldStart = (self.tasks.count == 0)
        
        objc_sync_enter(self.tasks)
        
        tasks.append(task)
        
        objc_sync_exit(self.tasks)
        
        if shouldStart {
            self.nextTask()
        }
        
        return task
    }
    
    func nextTask() {
        
        if let task = tasks.first {
            do {
                try task.startEncode()
                
                objc_sync_enter(self.tasks)
                
                self.tasks.removeFirst()
                
                objc_sync_exit(self.tasks)
                
            } catch {
                
            }
        }
    }
    
    

}
