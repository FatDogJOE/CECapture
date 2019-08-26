//
//  CECaptureEvent.swift
//  CECapture
//
//  Created by mac on 2019/8/15.
//

import UIKit
import Aspects
import RxSwift

enum CECaptureEventType {
    case unknow
    case touchDown(location:CGPoint)
    case touchUpInside(location:CGPoint)
    case touchUpOutside(location:CGPoint)
}

class CECaptureEvent: NSObject {
    
    static let share : CECaptureEvent = { return CECaptureEvent() }()
    
    let eventSubject : PublishSubject<(CECaptureEventType,UIView)> = PublishSubject()
    
    override init() {
        super.init()
    }
    
    func setup() {
        self.captureTouchBegin()
        self.captureTouchEnd()
        self.captureTouchMoved()
        self.captureTouchCancel()
        self.captureUIControlAction()
    }
    
    private func captureTouchBegin() {
        
        let block : @convention(block) (AnyObject?) -> Void = { info in
            
            let aspectInfo = info as! AspectInfo
            self.handleTouchBegin(touches: aspectInfo.arguments()[0] as! Set<UITouch>, event: aspectInfo.arguments()[1] as! UIEvent)
            
        }
        
        let blobj : AnyObject = unsafeBitCast(block, to: AnyObject.self)
        
        do {
            
            let selector = NSSelectorFromString("touchesBegan:withEvent:")
        
            try UIResponder.aspect_hook(selector, with: .positionBefore, usingBlock: blobj)
                
        } catch {
            
        }
        
    }
    
    private func captureTouchMoved() {
        
        let block : @convention(block) (AnyObject?) -> Void = { info in
            
            let aspectInfo = info as! AspectInfo
            self.handleTouchMoved(touches: aspectInfo.arguments()[0] as! Set<UITouch>, event: aspectInfo.arguments()[1] as! UIEvent)
            
        }
        
        let blobj : AnyObject = unsafeBitCast(block, to: AnyObject.self)
        
        do {
            
            let selector = NSSelectorFromString("touchesMoved:withEvent:")
            
            try UIResponder.aspect_hook(selector, with: .positionBefore, usingBlock: blobj)
            
        } catch {
            
        }
        
    }
    
    
    private func captureTouchEnd() {
        
        let block : @convention(block) (AnyObject?) -> Void = { info in
            
            let aspectInfo = info as! AspectInfo
            self.handleTouchEnd(touches: aspectInfo.arguments()[0] as! Set<UITouch>, event: aspectInfo.arguments()[1] as! UIEvent)
            
        }
        
        let blobj : AnyObject = unsafeBitCast(block, to: AnyObject.self)
        
        do {
            
            let selector = NSSelectorFromString("touchesEnded:withEvent:")
            
            try UIResponder.aspect_hook(selector, with: .positionBefore, usingBlock: blobj)
            
        } catch {
            
        }
        
    }
    
    private func captureTouchCancel() {
        
        let block : @convention(block) (AnyObject?) -> Void = { info in
            
            let aspectInfo = info as! AspectInfo
            self.handleTouchCancel(touches: aspectInfo.arguments()[0] as! Set<UITouch>, event: aspectInfo.arguments()[1] as! UIEvent)
            
        }
        
        let blobj : AnyObject = unsafeBitCast(block, to: AnyObject.self)
        
        do {
            
            let selector = NSSelectorFromString("touchesCancelled:withEvent:")
            
            try UIResponder.aspect_hook(selector, with: .positionBefore, usingBlock: blobj)
        } catch {
            
        }
        
    }
    
    private func captureUIControlAction() {
    
        let block : @convention(block) (AnyObject?) -> Void = { info in
            let aspectInfo = info as! AspectInfo
            let event = aspectInfo.arguments()[2] as! UIEvent
            if let touch = event.allTouches?.first {
                
                switch touch.phase {
                case UITouchPhase.began:
                    self.handleTouchBegin(touches: event.allTouches!, event: event)
                    break
                case UITouchPhase.moved:
                    self.handleTouchMoved(touches: event.allTouches!, event: event)
                    break
                case UITouchPhase.ended:
                    self.handleTouchEnd(touches: event.allTouches!, event: event)
                    break
                case UITouchPhase.cancelled:
                    self.handleTouchCancel(touches: event.allTouches!, event: event)
                    break
                case UITouchPhase.stationary:
                    break
                }
                
            }

        }
    
        let blobj : AnyObject = unsafeBitCast(block, to: AnyObject.self)
    
        do {
            
            let selector = NSSelectorFromString("sendAction:to:forEvent:")
            
            try UIControl.aspect_hook(selector, with: .positionBefore, usingBlock: blobj)
            
        } catch {
            
        }
    
    }
    
    private func eventForTouches(touches:Set<UITouch>, event:UIEvent) -> CECaptureEventType {
        
        if event.type == UIEventType.touches {
            
            let touch = touches.first
            let touchLocationInView = touch!.location(in: touch!.view)
            let touchViewFrame = touch!.view!
            
            guard touch != nil else {
                return .unknow
            }
            
            switch touch!.phase {
            case .began:
                return .touchDown(location: touch!.location(in: touch!.window!))
            case .ended:
                if touchViewFrame.bounds.contains(touchLocationInView) {
                    return .touchUpInside(location: touch!.location(in: touch!.window!))
                }else {
                    return .touchUpOutside(location: touch!.location(in: touch!.window!))
                }
            case .moved:
                return .unknow
            case .cancelled:
                return .unknow
            case .stationary:
                return .unknow
            }
        } else {
            return .unknow
        }
        
    }
    
    func handleTouchBegin(touches:Set<UITouch>, event:UIEvent) {
        let touch = touches.first

        if let window = touch?.window {
            self.eventSubject.onNext((self.eventForTouches(touches: touches, event: event),window))
        }
        
    }
    
    func handleTouchMoved(touches:Set<UITouch>, event:UIEvent) {
        
    }
    
    func handleTouchEnd(touches:Set<UITouch>, event:UIEvent) {
        let touch = touches.first
        
        if let window = touch?.window {
            self.eventSubject.onNext((self.eventForTouches(touches: touches, event: event),window))
        }
    }
    
    func handleTouchCancel(touches:Set<UITouch>, event:UIEvent) {
        
    }
    
}
