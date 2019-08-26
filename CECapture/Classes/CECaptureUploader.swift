//
//  CECaptureUploader.swift
//  CECapture
//
//  Created by mac on 2019/8/15.
//

import UIKit
import RxSwift
import Alamofire

class CECaptureUploader: NSObject {
    
    static let share : CECaptureUploader = { CECaptureUploader() }()
    
    let disposeBag = DisposeBag()
    let convert = CECaptureVideoGenerator()
    let videoMixer = CECaptureVideoMixer()
    let gifMixer = CECaptureGifMixer()
    
    var currentCacheName : String = ""
    var currentFolderPath : String {
        return self.screenshotsFolder + "/" + self.currentCacheName
    }
    var screenshotsFolder : String {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! + "/" + "ScreenShots".md5()
    }
    var gifFolder : String {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! + "/" + "GIF".md5()
    }

    func setup() {
        self.registerMixEvent()
        
        let notificationCenter = NotificationCenter.default
        
        notificationCenter.addObserver(self, selector: #selector(applicationWillEnterForground), name: Notification.Name.UIApplicationWillEnterForeground, object: nil)
        notificationCenter.addObserver(self, selector: #selector(applicationDidEnterBackground), name: Notification.Name.UIApplicationDidEnterBackground, object: nil)
        notificationCenter.addObserver(self, selector: #selector(applicationDidfinishLaunch), name: NSNotification.Name.UIApplicationDidFinishLaunching, object: nil)
        
        self.makeDirIfNotExist(path: self.screenshotsFolder)
        self.makeDirIfNotExist(path: self.gifFolder)
    }
    
    func makeDirIfNotExist(path:String) {
        if !FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.createDirectory(at: URL(fileURLWithPath: path),
                                                         withIntermediateDirectories: true,
                                                         attributes: nil)
            }catch {
                
            }
            
        }
    }
    
    func registerMixEvent() {
        
        CECaptureMix.share.screenShotSubject.asObserver().buffer(timeSpan: 10, count: 5, scheduler:  MainScheduler.instance).subscribe(onNext: {[weak self] (images) in
            self?.handleMixedScreenshots(screenshots: images)
        }).disposed(by: self.disposeBag)
        
    }
    
    func handleMixedScreenshots(screenshots:[(UIImage,TimeInterval)]) {
        
        DispatchQueue.global().async {
            
            for screenshot in screenshots {
                
                let jpegData = UIImageJPEGRepresentation(screenshot.0, 0.01)
                
                try? jpegData?.write(to: URL(fileURLWithPath: self.currentFolderPath + "/" + "\(screenshot.1).jpeg"))
                
            }
            
        }
        
    }
    
    func convertScreenshotsToGif() {
        
        DispatchQueue.global().async {
            
            let fileNames = try? FileManager.default.contentsOfDirectory(atPath: self.screenshotsFolder)
            
            for fileName in fileNames ?? [] {
                
                guard fileName != self.currentCacheName else {
                    continue
                }
                
                let images = self.images(in: self.screenshotsFolder + "/" + fileName)
                
                if images.count > 0 {
                    
                    let gifData = self.gifMixer.createGif(with: images)
                    
                    do {
                        try gifData.write(to: URL(fileURLWithPath: self.gifFolder + "/" + fileName + ".gif"))
                        try FileManager.default.removeItem(at: URL(fileURLWithPath: self.screenshotsFolder + "/" + fileName))
                    }catch {
                        continue
                    }
                    
                } else {
                    do {
                        try FileManager.default.removeItem(at: URL(fileURLWithPath: self.screenshotsFolder + "/" + fileName))
                    }catch {
                        continue
                    }
                }

            }
            
        }
        
    }
    
    
    func convertScreenshotsToVideo() {
        
        DispatchQueue.global().async {
            
            let fileNames = try? FileManager.default.contentsOfDirectory(atPath: self.screenshotsFolder)
            
            for fileName in fileNames ?? [] {
                
                let images = self.images(in: self.screenshotsFolder + "/" + fileName)
                
                if images.count > 0 {
                    
                    let img = images.first!
                    
                    do {
                        
                        try self.videoMixer.setupCompressionSession(width: Int32(img.size.width),
                                                                     height: Int32(img.size.height),
                                                                     fps: 30,
                                                                     bitrate: 2048,
                                                                     filePath: self.screenshotsFolder + "/" + fileName + ".h264")
                        try self.videoMixer.startEncodeImages(images: images)
                        
                    } catch {
                        
                    }
                    
                    
                }
            }
        }
    }
    
    func images(in directory:String) -> [UIImage]{
        
        let fileNames = try? FileManager.default.contentsOfDirectory(atPath: directory)
        
        var result : [UIImage] = []
        
        for fileName in fileNames ?? [] {
            
            if let image = UIImage(contentsOfFile: directory + "/" + fileName) {
                result.append(self.scaleImage(source: image, scale: 0.25))
            }
            
        }
        
        return result
    }
    
    func scaleImage(source image:UIImage, scale:CGFloat) -> UIImage {
        
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        
        UIGraphicsBeginImageContext(newSize)
        
        image.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return newImage!
        
    }
    
    func uploadScreenshots() {
        
//        DispatchQueue.global().async {
//
//            let fileNames = try? FileManager.default.contentsOfDirectory(atPath: self.screenshotsFolder)
//
//            for fileName in fileNames ?? [] {
//
//                let zipPath = self.screenshotsFolder + "/" + fileName
//
//                Alamofire.upload(URL(fileURLWithPath: zipPath), to: URL(string: "")!).response(completionHandler: { (response) in
//
//                    if response.response?.statusCode == 200 {
//                        try? FileManager.default.removeItem(at: URL(fileURLWithPath: zipPath))
//                    } else {
//
//                    }
//
//                })
//
//            }
        
//        }
        
    }
    
   
    @objc func applicationDidfinishLaunch() {
        self.currentCacheName = "\(Date().timeIntervalSince1970 * 1000)".md5()
        self.makeDirIfNotExist(path: self.currentFolderPath)
        self.convertScreenshotsToGif()
    }
    
    @objc func applicationDidEnterBackground() {
        
    }
    
    @objc func applicationWillEnterForground() {
        self.currentCacheName = "\(Date().timeIntervalSince1970 * 1000)".md5()
        self.makeDirIfNotExist(path: self.currentFolderPath)
        self.convertScreenshotsToGif()
    }
    
}
