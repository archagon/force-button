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
    private let snapThreshhold: Double = 0.4
    
    // AB: at the moment we don't support direct setting/getting of control state, but we can still use this mapping
    let stateToT: [UIControlState:Double] = [
        .normal: 0,                                             //off
        .highlighted: self.snapThreshhold + 0.1,                //max past on
        .selected: self.snapThreshhold,                         //on
        [.selected, .highlighted]: self.snapThreshhold + 0.1    //not currently used
    ]
    
    // TODO: replace w/UIControlState
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
    
    private var panGestureRecognizer: SimpleMovementGestureRecognizer!
    private var tapGestureRecognizer: UIGestureRecognizer!
    private var deepTouchGestureRecognizer: DeepTouchGestureRecognizer!
    private var ignoreGestureRecognizerActions: Bool = false //enabled when we snap into the on position
    private var hapticGenerator: UIImpactFeedbackGenerator!
    
    private var animationDisplayLink: CADisplayLink?
    private var animation: (delay: Double, start: Double, end: Double, startTime: TimeInterval, duration: TimeInterval, function: ((Double)->Double))? {
        didSet {
            self.animationDisplayLink?.invalidate()
            self.animationDisplayLink = nil
            
            if animation != nil {
                let animationDisplayLink = CADisplayLink.init(target: self, selector: #selector(animation(displayLink:)))
                animationDisplayLink.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
                self.animationDisplayLink = animationDisplayLink
            }
        }
    }
    
    private var initialTouchPosition: CGPoint?
    private var cancellationRadius: Double = 16
    
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

        let targetState: UIControlState
        switch newValue {
        case .off:
            break
        case .toOn:
            break
        case .on:
            break
        case .toOff:
            break
        }
        
        if animated {
            func dampenedSine(_ t: Double) -> Double {
                let initialAmplitude: Double = 0.25
                let decayConstant: Double = 5
                let numberOfBounces: Double = 2
                let angularFrequency: Double = 2 * M_PI * numberOfBounces
                
                return initialAmplitude * pow(M_E, -decayConstant * t) * sin(angularFrequency * t)
            }
            
            func easeOutCubic(_ t: Double) -> Double {
                return max(min(1 - pow(1 - t, 3), 1), 0)
            }
            
            if oldValue.isOff && newValue.isOn {
                animateSnap: do {
                    self.animation = (
                        delay: 0,
                        start: self.snapThreshhold,
                        end: self.snapThreshhold + 0.4,
                        startTime: TimeInterval(CFAbsoluteTimeGetCurrent()),
                        duration: TimeInterval(0.5),
                        function: dampenedSine
                    )
                }
            }
            
            if newValue == .off {
                animateToZero: do {
                    self.animation = (
                        delay: 0,
                        start: self.t,
                        end: 0,
                        startTime: TimeInterval(CFAbsoluteTimeGetCurrent()),
                        duration: TimeInterval(0.1),
                        function: easeOutCubic
                    )
                }
            }
        }
        else {
            self.t = (newValue.isOn ? self.deepTouchGestureRecognizer.nonForceDefaultValue : 0)
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
        
//        self.tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapAction(recognizer:)))
//        self.tapGestureRecognizer.delegate = self
//        self.addGestureRecognizer(self.tapGestureRecognizer)
        
        self.panGestureRecognizer = SimpleMovementGestureRecognizer(target: self, action: #selector(tapEvents(recognizer:)))
        self.addGestureRecognizer(self.panGestureRecognizer)
        
        self.deepTouchGestureRecognizer = DeepTouchGestureRecognizer(target: self, action: #selector(action(recognizer:)), forceScaleFactor: 1.25)
        self.deepTouchGestureRecognizer.delegate = self
        self.addGestureRecognizer(self.deepTouchGestureRecognizer)
        
        self.deepTouchGestureRecognizer.nonForceDefaultValue = self.snapThreshhold
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if self.traitCollection.forceTouchCapability == .unavailable {
            self.deepTouchGestureRecognizer.isEnabled = false
        }
        else if self.traitCollection.forceTouchCapability == .available {
            self.deepTouchGestureRecognizer.isEnabled = true
        }
        // and do nothing on 'unknown'
    }
    
    @objc func tapAction(recognizer: UITapGestureRecognizer) {
        let old = self.displayState
        let new: State = (old.isOn ? .off : .on)
        
        self.displayState = new
        
        self.sendActions(for: .valueChanged)
    }
    
    var tapStartingConditions: (position: CGPoint, time: TimeInterval, value: Bool)?
    let tapMaxDistancePastBounds = CGFloat(10)
    @objc func tapEvents(recognizer: UIPanGestureRecognizer) {
        func pointInsideTapBounds(_ p: CGPoint) -> Bool {
            return !(p.x >= self.bounds.size.width + tapMaxDistancePastBounds ||
                p.x <= -tapMaxDistancePastBounds ||
                p.y >= self.bounds.size.height + tapMaxDistancePastBounds ||
                p.y <= -tapMaxDistancePastBounds)
        }
        
        switch recognizer.state {
        case .began:
            fallthrough
        case .changed:
            if self.tapStartingConditions == nil {
                self.tapStartingConditions = (position: recognizer.location(in: nil), time: CACurrentMediaTime(), value: self.on)
            }
            
            if let startingConditions = self.tapStartingConditions {
                let p0 = startingConditions.position
                let p1 = recognizer.location(in: nil)
                let l = sqrt(pow(p1.x - p0.x, 2) + pow(p1.y - p0.y, 2))
                
                let localPoint = self.convert(p1, from: nil)
                if !pointInsideTapBounds(localPoint) {
                    self.displayState = (startingConditions.value ? .on : .off)
                }
                else {
                    self.displayState = (!startingConditions.value ? .on : .off)
                }
                
            }
            
            break
        case .ended:
            let p1 = recognizer.location(in: nil)
            let localPoint = self.convert(p1, from: nil)
            if pointInsideTapBounds(localPoint) {
                self.sendActions(for: .valueChanged)
            }
            
            self.tapStartingConditions = nil

            break
        case .cancelled:
            if let startingConditions = self.tapStartingConditions {
                self.displayState = (startingConditions.value ? .on : .off)
            }
            
            // go back to starting state, but make sure we play nice with deep touch (if present)
            
            self.tapStartingConditions = nil
            
            break
        default:
            self.tapStartingConditions = nil
            
            break
        }
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
//        if gestureRecognizer == self.tapGestureRecognizer {
        if false {
            return false
        }
        else if gestureRecognizer == self.deepTouchGestureRecognizer {
//            if otherGestureRecognizer == self.tapGestureRecognizer {
            if false {
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
    
    // AB: Tap recognition. We do this here instead of in a gesture recognizer because, while the button action only
    // happens when the user takes their finger off the button (as in a tap), the button can still change visual state 
    // if they move their finger past a certain radius or back in (like a UIButton).  This doesn't fall in line with 
    // the recognized/unrecognized single-state nature of gesture recognizers. At best, we'd be using a pan gesture
    // recognizer and doing our processing in this class anyway.
    
//    var tapStartingConditions: (touch: UITouch, position: CGPoint)?
//    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//        if self.tapStartingConditions == nil, let touch = (touches as NSSet).anyObject() as? UITouch {
//            self.tapStartingConditions = (touch: touch, position: touch.location(in: nil))
//        }
//    }
//    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
//        print("touches moved")
//    }
//    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
//        print("touches ended")
//    }
//    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
//        print("touches cancelled")
//    }

    // pan gesture recognizers have a minimum radius, which is unacceptable for our use case
    class SimpleMovementGestureRecognizer: UIGestureRecognizer {
        private var firstTouch: UITouch?

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesBegan(touches, with: event)
            
            if self.state == .possible, self.firstTouch == nil, let touch = touches.first {
                self.firstTouch = touch
                self.state = .began
            }
            
            for touch in touches {
                if touch != self.firstTouch {
                    self.ignore(touch, for: event)
                }
            }
        }
        
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesMoved(touches, with: event)
            
            if let touch = self.firstTouch, touches.contains(touch) {
                self.state = .changed
            }
        }
        
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesEnded(touches, with: event)
            
            if let touch = self.firstTouch, touches.contains(touch) {
                self.firstTouch = nil
                self.state = .ended
            }
        }
        
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesCancelled(touches, with: event)
            
            if let touch = self.firstTouch, touches.contains(touch) {
                self.firstTouch = nil
                self.state = .cancelled
            }
        }
    }
    
    // less of a gesture; more of a pressure sensor
    class DeepTouchGestureRecognizer: UIGestureRecognizer {
        var minimumForce: Double = 0.15 //standard-ish tap
        var nonForceDefaultValue: Double = 1
        
        private(set) var t: Double = 0
        var forceScaleFactor: Double
        
        private var firstTouch: UITouch?
        
        required init(target: AnyObject?, action: Selector, forceScaleFactor: Double) {
            self.forceScaleFactor = forceScaleFactor
            
            super.init(target: target, action: action)
        }
        
        private func force(_ touch: UITouch) -> Double {
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
                return self.nonForceDefaultValue
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
            
            for touch in touches {
                if touch != self.firstTouch {
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
