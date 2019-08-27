//
//  CECaptureMix.swift
//  CECapture
//
//  Created by mac on 2019/8/15.
//

import UIKit
import RxSwift

class CECaptureMix: NSObject {
    
    static let share : CECaptureMix = { return CECaptureMix() }()
    
    let disposeBag = DisposeBag()
    
    let screenShotSubject : PublishSubject<(UIImage, TimeInterval)> = PublishSubject()
    
    override init() {
        super.init()
    }
    
    func setup() {
         self.registerEvent()
    }
    
    func registerEvent() {
        
        CECaptureEvent.share.eventSubject.buffer(timeSpan: 3, count: 10, scheduler: MainScheduler.instance).subscribe(onNext: {[weak self] (events) in
            self?.handleCaptureEvents(events: events)
        }).disposed(by: self.disposeBag)
        
    }
    
    func handleCaptureEvents(events:[(CECaptureEventType,UIView)]) {
        
        for event in events {

            switch event.0 {
            case .touchDown(let location):
                self.screenShotSubject.onNext((self.makeScreenshot(view: event.1, touchLocations: [location]), Date().timeIntervalSince1970 * 1000))
                break
            case .touchUpInside(let location):
                self.screenShotSubject.onNext((self.makeScreenshot(view: event.1, touchLocations: [location]), Date().timeIntervalSince1970 * 1000))
                break
            case .touchUpOutside(let location):
                self.screenShotSubject.onNext((self.makeScreenshot(view: event.1, touchLocations: [location]), Date().timeIntervalSince1970 * 1000))
                break
            default:
                break
            }

        }
    
    }
    
    func makeScreenshot(view:UIView, touchLocations:[CGPoint]) -> UIImage {
        
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, 0.0)
        
        let context = UIGraphicsGetCurrentContext()!
        
        view.layer.render(in: context)
        
        UIColor.blue.withAlphaComponent(0.5).setFill()
        
        for touchLocation in touchLocations {
            context.addArc(center: touchLocation, radius: 20, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)
        }
        
        context.fillPath()
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return image!
        
    }
}
