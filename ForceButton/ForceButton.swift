//
//  ForceButton.swift
//  ForceButton
//
//  Created by Alexei Baboulevitch on 2016-10-5.
//  Copyright © 2016 Alexei Baboulevitch. All rights reserved.
//

import UIKit
import UIKit.UIGestureRecognizerSubclass

class ForceButton: UIControl, UIGestureRecognizerDelegate {
    enum State {
        case off //no touches
        case toOn //gesturing to snap point
        case on //past snap point
        case toOff //gesturing back to off from on state
        
        var isOn: Bool {
            get {
                return self == .on
            }
        }
        var isOff: Bool {
            get {
                return !self.isOn
            }
        }
    }
    
    var tapticStyle: UIImpactFeedbackStyle? = .medium {
        didSet {
            if let style = tapticStyle {
                self.hapticGenerator = UIImpactFeedbackGenerator(style: style)
            }
        }
    }
    
    var renderBlock: ((_ t: Double, _ threshhold: Double, _ rect: CGRect, _ bounds: CGRect, _ state: State)->())?
    
    private var deepTouchGestureRecognizer: DeepTouchGestureRecognizer!
    private var ignoreGestureRecognizerActions: Bool = false //enabled when we snap into the on position
    private var hapticGenerator: UIImpactFeedbackGenerator!
    
    private var animationDisplayLink: CADisplayLink?
    private var animation: (delay: Double, start: Double, end: Double, startTime: TimeInterval, duration: TimeInterval, function: ((Double)->Double))?
    
    private var initialTouchPosition: CGPoint?
    private var cancellationRadius: Double = 4
    
    private var threshhold: Double = 0.4
    private var t: Double = 0 {
        didSet {
            self.setNeedsDisplay()
            
            if self.displayState == .toOn, self.tapticStyle != nil {
                self.hapticGenerator.prepare()
            }
        }
    }
    private var displayState: State = .off {
        didSet {
            func dampenedSine(_ t: Double) -> Double {
                let initialAmplitude: Double = 1
                let decayConstant: Double = 3
                let numberOfBounces: Double = 3
                let angularFrequency: Double = 2 * M_PI * numberOfBounces
                
                return initialAmplitude * pow(M_E, -decayConstant * t) * sin(angularFrequency * t)
            }
            
            func easeOutCubic(_ t: Double) -> Double {
                return max(min(1 - pow(1 - t, 3), 1), 0)
            }
            
            cancelExistingAnimation: do {
                self.animationDisplayLink?.invalidate()
                self.animationDisplayLink = nil
                self.animation = nil
            }
            
            if oldValue.isOff && displayState.isOn {
                // snapping to the on position
                
                self.sendActions(for: .valueChanged)
                
                if self.tapticStyle != nil {
                    self.hapticGenerator.impactOccurred()
                }
                
                animateSnap: do {
                    self.animationDisplayLink?.invalidate()
                    self.animation = (
                        delay: 0,
                        start: self.threshhold,
                        end: self.threshhold + 0.4,
                        startTime: TimeInterval(CFAbsoluteTimeGetCurrent()),
                        duration: TimeInterval(0.5),
                        function: dampenedSine)
                    
                    let animationDisplayLink = CADisplayLink.init(target: self, selector: #selector(animation(displayLink:)))
                    animationDisplayLink.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
                    self.animationDisplayLink = animationDisplayLink
                }
            }
            
            if displayState == .off {
                animateToZero: do {
                    self.animationDisplayLink?.invalidate()
                    self.animation = (
                        delay: 0,
                        start: self.t,
                        end: 0,
                        startTime: TimeInterval(CFAbsoluteTimeGetCurrent()),
                        duration: TimeInterval(0.1),
                        function: easeOutCubic)
                    
                    let animationDisplayLink = CADisplayLink.init(target: self, selector: #selector(animation(displayLink:)))
                    animationDisplayLink.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
                    self.animationDisplayLink = animationDisplayLink
                }
            }
        }
    }
    
    var on: Bool {
        get {
            return self.displayState.isOn
        }
        set {
            if !newValue {
                self.displayState = .off
            }
            else {
                self.displayState = .on
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        if let style = self.tapticStyle {
            self.hapticGenerator = UIImpactFeedbackGenerator(style: style)
        }
        
        self.isOpaque = false
        
        self.deepTouchGestureRecognizer = DeepTouchGestureRecognizer(target: self, action: #selector(action(recognizer:)), forceScaleFactor: 1.25)
        self.deepTouchGestureRecognizer.delegate = self
        self.addGestureRecognizer(self.deepTouchGestureRecognizer)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func action(recognizer: DeepTouchGestureRecognizer) {
        if !self.ignoreGestureRecognizerActions {
            switch recognizer.state {
                
            case .began:
                self.initialTouchPosition = recognizer.location(in: self)
                
                switch self.displayState {
                case .off:
                    self.displayState = .toOn
                    break
                case .on:
                    self.displayState = .toOff
                    break
                default:
                    break
                }
                
                fallthrough
            case .changed:
                // cancel recognizer if touch strays too far
                if let p0 = self.initialTouchPosition {
                    let p1 = recognizer.location(in: self)
                    let distance = abs(sqrt(pow(Double(p1.x - p0.x), 2) + pow(Double(p1.y - p0.y), 2)))
                    if distance >= self.cancellationRadius {
                        recognizer.isEnabled = false
                        recognizer.isEnabled = true
                    }
                }
                
                if self.displayState == .toOn {
                    self.t = recognizer.t
                }
                else if self.displayState == .toOff {
                    self.t = self.threshhold + log10(1 + recognizer.t)
                }
                
                if self.displayState == .toOn {
                    if self.t >= self.threshhold {
                        self.ignoreGestureRecognizerActions = true
                        self.displayState = .on
                    }
                }
                
                break
                
            case .ended:
                fallthrough
            case .cancelled:
                if self.displayState.isOn {
                    self.displayState = .on
                }
                else {
                    self.displayState = .off
                }
                
                break
                
            default:
                break
                
            }
        }
        
        // cancel ignored actions on end of gesture
        switch recognizer.state {
            
        case .ended:
            fallthrough
        case .cancelled:
            fallthrough
        case .failed:
            self.ignoreGestureRecognizerActions = false
            break
            
        default:
            break
            
        }
    }
    
    @objc func animation(displayLink: CADisplayLink) {
        guard let animation = self.animation else {
            self.animationDisplayLink?.invalidate()
            self.animationDisplayLink = nil
            return
        }
        
        let actualStartTime = animation.startTime + animation.delay
        let time = TimeInterval(CFAbsoluteTimeGetCurrent())
        let t = max(min(Double((time - actualStartTime) / animation.duration), 1), 0)
        let actualT = animation.function(t)
        let delta = animation.end - animation.start
        let value = animation.start + delta * actualT
        
        self.t = value
        
        if t >= 1 {
            self.animation = nil
            self.animationDisplayLink?.invalidate()
            self.animationDisplayLink = nil
        }
    }
    
    override func draw(_ rect: CGRect) {
        if let block = renderBlock {
            block(self.t, self.threshhold, rect, self.bounds, self.displayState)
        }
    }
    
    // prevents gesture from eating up scroll view pan
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // TODO: there's gotta be some better way to do this! we want to make it so that any other gesture causes this one to fail
        if otherGestureRecognizer.state == .recognized || otherGestureRecognizer.state == .began  {
            gestureRecognizer.isEnabled = false
            gestureRecognizer.isEnabled = true
        }
        
        return true
    }

    // less of a gesture; more of a pressure sensor
    class DeepTouchGestureRecognizer: UIGestureRecognizer {
        
        private(set) var t: Double = 0
        var forceScaleFactor: Double
        
        private var firstTouch: UITouch?
        
        required init(target: AnyObject?, action: Selector, forceScaleFactor: Double) {
            self.forceScaleFactor = forceScaleFactor
            
            super.init(target: target, action: action)
        }
        
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesBegan(touches, with: event)
            
            self.state = .began
            
            if self.firstTouch == nil, let touch = touches.first {
                self.firstTouch = touch
                self.t = Double(touch.force / touch.maximumPossibleForce) * self.forceScaleFactor
            }
            else {
                for touch in touches {
                    self.ignore(touch, for: event)
                }
            }
        }
        
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesMoved(touches, with: event)
            
            self.state = .changed
            
            if let touch = self.firstTouch, touches.contains(touch) {
                self.t = Double(touch.force / touch.maximumPossibleForce) * self.forceScaleFactor
            }
        }
        
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesEnded(touches, with: event)
            
            self.t = 0
            self.firstTouch = nil
            
            self.state = .ended
        }
        
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesCancelled(touches, with: event)
            
            self.t = 0
            self.firstTouch = nil
            
            self.state = .cancelled
        }
    }
}
