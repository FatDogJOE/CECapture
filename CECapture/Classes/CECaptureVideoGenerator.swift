//
//  CECaptureVideoGenerator.swift
//  Alamofire
//
//  Created by mac on 2019/8/15.
//

import UIKit
import MediaPlayer
import AVFoundation
import CoreGraphics
import VideoToolbox


enum PixelBufferError:Error {
    case imageIsNil
    case invalidPixcelBuffer
}


class CECaptureVideoGenerator: NSObject {
    
    let fps = 1
    
    func convertImagesToVideo(images:[UIImage], videoURL:URL) {
        
        guard images.count > 0 else {
            return
        }
        
        let image = images.first
        
        let size = CGSize(width: image!.size.width, height: image!.size.height)
        
        var videoWriter : AVAssetWriter?
        
        do {
            videoWriter = try AVAssetWriter(outputURL: videoURL, fileType: .mov)
        } catch {
            return
        }
        
        let videoSettings = [AVVideoCodecKey:AVVideoCodecH264, AVVideoWidthKey:size.width, AVVideoHeightKey:size.height] as [String : Any]
        
        let writeInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        
        let pixelBufferAttributes = [kCVPixelBufferPixelFormatTypeKey:kCVPixelFormatType_32ARGB] as [String: Any]
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writeInput, sourcePixelBufferAttributes: pixelBufferAttributes)
        
        guard videoWriter?.canAdd(writeInput) ?? false else {
            return
        }
        
        videoWriter?.add(writeInput)
        
        videoWriter?.startWriting()
        
        videoWriter?.startSession(atSourceTime: kCMTimeZero)
        
        var currentIndex = 0
        
        writeInput.requestMediaDataWhenReady(on: DispatchQueue.global()) {

            while(writeInput.isReadyForMoreMediaData) {

                
                
                if currentIndex >= images.count * self.fps {
                    writeInput.markAsFinished()
                    videoWriter?.finishWriting(completionHandler: {

                    })
                    break
                }

                do {

                    let buffer = try self.pixelBuffer(for: images[Int(currentIndex / self.fps)].cgImage)
                    
                    let time = CMTime(value: CMTimeValue(currentIndex), timescale: CMTimeScale(self.fps))
                    
                    if writeInput.isReadyForMoreMediaData {
                        _ = adaptor.append(buffer, withPresentationTime: time)
                    }
                                        
                } catch {

                }
                
                currentIndex += 1

            }

        }
        
    }
    
    private func pixelBuffer(for image:CGImage?) throws -> CVPixelBuffer {
        
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
        
        
        defer {
            buffer.deallocate()
        }
        
        return buffer.pointee!
        
    }

}
