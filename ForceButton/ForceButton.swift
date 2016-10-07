//
//  ForceButton.swift
//  ForceButton
//
//  Created by Alexei Baboulevitch on 2016-10-5.
//  Copyright © 2016 Alexei Baboulevitch. All rights reserved.
//

import UIKit
import UIKit.UIGestureRecognizerSubclass

// TODO: when moving past detection radius, we should be able to un-cancel our touch, like UIButtons do
// TODO: we should be able to cancel an off touch

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
    
    var tBlock: ((_ t: Double, _ threshhold: Double, _ bounds: CGRect, _ state: State)->())?
    var renderBlock: ((_ t: Double, _ threshhold: Double, _ rect: CGRect, _ bounds: CGRect, _ state: State)->())? {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    private var tapGestureRecognizer: UIGestureRecognizer!
    private var deepTouchGestureRecognizer: DeepTouchGestureRecognizer!
    private var ignoreGestureRecognizerActions: Bool = false //enabled when we snap into the on position
    private var hapticGenerator: UIImpactFeedbackGenerator!
    
    private var animationDisplayLink: CADisplayLink?
    private var animation: (delay: Double, start: Double, end: Double, startTime: TimeInterval, duration: TimeInterval, function: ((Double)->Double))?
    
    private var initialTouchPosition: CGPoint?
    private var cancellationRadius: Double = 16
    
    private var snapThreshhold: Double = 0.4
    private var t: Double = 0 {
        didSet {
            self.setNeedsDisplay()
            
            if let block = self.tBlock {
                block(self.t, self.snapThreshhold, self.bounds, self.displayState)
            }
            
            // TODO: this doesn't really belong here
            if self.displayState == .toOn, self.tapticStyle != nil {
                self.hapticGenerator.prepare()
            }
        }
    }
    
    private var _displayState: State = .off
    private var displayState: State {
        get {
            return self._displayState
        }
        set {
            self.setDisplayState(newValue, animated: true)
        }
    }
    private func setDisplayState(_ state: State, animated: Bool) {
        let oldValue = self._displayState
        let newValue = state
        self._displayState = state
        
        cancelExistingAnimation: do {
            self.animationDisplayLink?.invalidate()
            self.animationDisplayLink = nil
            self.animation = nil
        }
        
        if animated {
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
            
            if oldValue.isOff && newValue.isOn {
                animateSnap: do {
                    self.animationDisplayLink?.invalidate()
                    self.animation = (
                        delay: 0,
                        start: self.snapThreshhold,
                        end: self.snapThreshhold + 0.4,
                        startTime: TimeInterval(CFAbsoluteTimeGetCurrent()),
                        duration: TimeInterval(0.5),
                        function: dampenedSine)
                    
                    let animationDisplayLink = CADisplayLink.init(target: self, selector: #selector(animation(displayLink:)))
                    animationDisplayLink.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
                    self.animationDisplayLink = animationDisplayLink
                }
            }
            
            if newValue == .off {
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
        else {
            self.t = (newValue.isOn ? 1 : 0)
        }
    }
    
    var on: Bool {
        get {
            return self.displayState.isOn
        }
        set {
            if !newValue {
                setDisplayState(.off, animated: false)
            }
            else {
                setDisplayState(.on, animated: false)
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        if let style = self.tapticStyle {
            self.hapticGenerator = UIImpactFeedbackGenerator(style: style)
        }
        
        self.isOpaque = false
        
        self.tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapAction(recognizer:)))
        self.tapGestureRecognizer.delegate = self
        self.addGestureRecognizer(self.tapGestureRecognizer)
        
        self.deepTouchGestureRecognizer = DeepTouchGestureRecognizer(target: self, action: #selector(action(recognizer:)), forceScaleFactor: 1.25)
        self.deepTouchGestureRecognizer.delegate = self
        self.addGestureRecognizer(self.deepTouchGestureRecognizer)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func tapAction(recognizer: UITapGestureRecognizer) {
        let old = self.displayState
        let new: State = (old.isOn ? .off : .on)
        
        self.displayState = new
        
        self.sendActions(for: .valueChanged)
    }
    
    @objc func action(recognizer: DeepTouchGestureRecognizer) {
        // ensures sendActions is called when needed; can't do it in displayState didSet b/c on property can also be changed
        // manually, i.e. we only want it called on user input, which is all handled here
        func setDisplayState(_ new: State) {
            let old = self.displayState
            
            self.displayState = new
            
            if old.isOn != new.isOn {
                self.sendActions(for: .valueChanged)
            }
            
            if !old.isOn && new.isOn, self.tapticStyle != nil {
                self.hapticGenerator.impactOccurred()
            }
        }
        
        if !self.ignoreGestureRecognizerActions {
            switch recognizer.state {
                
            case .began:
                self.initialTouchPosition = recognizer.location(in: self)
                
                switch self.displayState {
                case .off:
                    setDisplayState(.toOn)
                    break
                case .on:
                    setDisplayState(.toOff)
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
                    self.t = self.snapThreshhold + log10(1 + recognizer.t)
                }
                
                if self.displayState == .toOn {
                    if self.t >= self.snapThreshhold {
                        self.ignoreGestureRecognizerActions = true
                        setDisplayState(.on)
                    }
                }
                
                break
                
            case .ended:
                fallthrough
            case .cancelled:
                if self.displayState.isOn {
                    setDisplayState(.on)
                }
                else {
                    setDisplayState(.off)
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
            block(self.t, self.snapThreshhold, rect, self.bounds, self.displayState)
        }
    }
    
    // prevents gesture from eating up scroll view pan
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == self.tapGestureRecognizer {
            return false
        }
        else if gestureRecognizer == self.deepTouchGestureRecognizer {
            if otherGestureRecognizer == self.tapGestureRecognizer {
                return false
            }
            else {
            // TODO: there's gotta be some better way to do this! we want to make it so that any other gesture causes this one to fail
                if otherGestureRecognizer.state == .recognized || otherGestureRecognizer.state == .began || otherGestureRecognizer.state == .changed  {
                    gestureRecognizer.isEnabled = false
                    gestureRecognizer.isEnabled = true
                }
                
                return true
            }
        }
        
        return false
    }

    // less of a gesture; more of a pressure sensor
    class DeepTouchGestureRecognizer: UIGestureRecognizer {
        var minimumForce: Double = 0.15 //standard-ish tap
        
        private(set) var t: Double = 0
        var forceScaleFactor: Double
        
        private var firstTouch: UITouch?
        
        required init(target: AnyObject?, action: Selector, forceScaleFactor: Double) {
            self.forceScaleFactor = forceScaleFactor
            
            super.init(target: target, action: action)
        }
        
        private func force(_ touch: UITouch) -> Double {
            let nonForceValue: Double = 1
            
            var shouldCheckForce = true
            
            if let view = self.view, view.traitCollection.forceTouchCapability != .available {
                shouldCheckForce = false
            }
            
            if touch.maximumPossibleForce == 0 {
                shouldCheckForce = false
            }
            
            if shouldCheckForce {
                return Double(max(min(touch.force / touch.maximumPossibleForce, 1), 0))
            }
            else {
                return nonForceValue
            }
        }
        
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesBegan(touches, with: event)
            
            if self.state == .possible, self.firstTouch == nil, let touch = touches.first {
                let t = force(touch)
                
                if force(touch) >= self.minimumForce {
                    self.firstTouch = touch
                    self.t = t
                    self.state = .began
                }
            }
            else {
                for touch in touches {
                    self.ignore(touch, for: event)
                }
            }
        }
        
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesMoved(touches, with: event)
            
            // BUGFIX: fun fact -- if you don't change your state to .began or .changed, you won't get a touchesCancelled
            // call on gesture cancellation! this means we can't persist touches until we're past the threshhold
            if self.state == .possible, self.firstTouch == nil, let touch = touches.first {
                let t = force(touch)
                
                if force(touch) >= self.minimumForce {
                    self.firstTouch = touch
                    self.t = t
                    self.state = .began
                }
            }
            else if let touch = self.firstTouch, touches.contains(touch) {
                let t = force(touch)
                
                self.t = t
                self.state = .changed
            }
        }
        
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesEnded(touches, with: event)
            
            if let touch = self.firstTouch, touches.contains(touch) {
                self.t = 0
                self.firstTouch = nil
                
                self.state = .ended
            }
        }
        
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesCancelled(touches, with: event)
            
            if let touch = self.firstTouch, touches.contains(touch) {
                self.t = 0
                self.firstTouch = nil
                
                self.state = .cancelled
            }
        }
    }
}
