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
    // AB: There are two types of state to track here. First, there's the value state — on or off. This is stored
    // as a separate property and causes the button to change its display state. The second is the display
    // state provided by UIControl. This is what actually corresponds to the visible button state. By default,
    // display state changes are animated.
    
    // MARK: - Properties -
    
    // MARK: Public
    
    var tapticStyle: UIImpactFeedbackStyle? = .medium {
        didSet {
            if let style = tapticStyle {
                self.hapticGenerator = UIImpactFeedbackGenerator(style: style)
            }
        }
    }
    
    var tBlock: ((_ t: Double, _ threshhold: Double, _ bounds: CGRect, _ state: UIControlState, _ value: Bool)->())?
    var renderBlock: ((_ t: Double, _ threshhold: Double, _ rect: CGRect, _ bounds: CGRect, _ state: UIControlState, _ value: Bool)->())? {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    var on: Bool = false {
        didSet {
            // KLUDGE: prevents isSelected from overwriting isHighlighted; also causes update to be called a few extra times
            let oldState = self.state
            self.isHighlighted = false
            self.isSelected = on
            self.updateDisplayState(oldValue: oldState, animated: true)
        }
    }
    
    // MARK: Appearance Constants, Etc.
    
    // TODO: at the moment we only SORT OF support control state, but it's still good to set up the framework
    private let statesContributingToAppearance: [UIControlState] = [.selected, .highlighted]
    private let stateT: [UIControlState:Double] = [
        .normal: 0,                     //off
        .highlighted: 0.5,              //off->on highlight
        .selected: 0.4,                 //on
        [.selected, .highlighted]: 0.5  //on->off highlight
    ]
    private static let stateTransitionQuick: TimeInterval = 2.1
    private static let stateTransitionLong: TimeInterval = stateTransitionQuick
    private let stateTransitionToDuration: [UIControlState:[UIControlState:TimeInterval]] = [
        .normal: [
            .highlighted: stateTransitionQuick,
            .selected: stateTransitionLong
        ],
        .highlighted: [
            .normal: stateTransitionQuick,
            .selected: stateTransitionQuick
        ],
        .selected: [
            .normal: stateTransitionLong,
            [.selected, .highlighted]: stateTransitionQuick
        ],
        [.selected, .highlighted]: [
            .selected: stateTransitionQuick,
            .normal: stateTransitionQuick
        ]
    ]
    private let stateTransitionToTweeningFunction: [UIControlState:[UIControlState:((Double)->Double)]] = [
        .normal: [
//            .highlighted: dampenedSine,
            .highlighted: easeOutCubic,
            .selected: easeOutCubic
        ],
        .highlighted: [
//            .normal: dampenedSine,
            .normal: easeOutCubic,
            .selected: easeOutCubic
        ],
        .selected: [
//            .normal: dampenedSine,
            .normal: easeOutCubic,
            [.selected, .highlighted]: easeOutCubic
        ],
        [.selected, .highlighted]: [
            .selected: easeOutCubic,
            .normal: easeOutCubic
//            .normal: dampenedSine
        ]
    ]
    
    private let snapThreshhold: Double = 0.4
    private let cancellationRadius: Double = 16
    
    // MARK: Display State
    
    private func updateDisplayState(oldValue: UIControlState, animated: Bool) {
        // AB: only some of the UIControl states affect appearance
        func condenseState(_ state: UIControlState) -> UIControlState {
            var returnState: UIControlState = .normal
            for substate in self.statesContributingToAppearance {
                if state.contains(substate) {
                    returnState.insert(substate)
                }
            }
            return returnState
        }
        
        let oldValue = condenseState(oldValue)
        let newValue = condenseState(self.state)
        
        //print("going from state \(oldValue.description) to state \(newValue.description)")
        
        if oldValue == newValue {
            return
        }
        
        guard let targetT: Double = self.stateT[newValue] else {
            assert(false, "unable to handle state transition from \(oldValue.description) to \(newValue.description)")
            return
        }
        
        if animated {
            guard
                let tweeningFunction = self.stateTransitionToTweeningFunction[oldValue]?[newValue],
                let duration = self.stateTransitionToDuration[oldValue]?[newValue] else
            {
                assert(false, "unable to handle state transition from \(oldValue.description) to \(newValue.description)")
                self.t = targetT
                return
            }
            
            self.animation = (
                delay: 0,
                start: self.t,
                end: targetT,
                startTime: TimeInterval(CFAbsoluteTimeGetCurrent()),
                duration: duration,
                function: tweeningFunction
            )
        }
        else {
            self.t = targetT
        }
    }
    
    override var isHighlighted: Bool {
        didSet {
            if oldValue != isHighlighted {
                var oldState = self.state
                
                if oldValue {
                    oldState.insert(.highlighted)
                }
                else {
                    oldState.remove(.highlighted)
                }
                
                self.updateDisplayState(oldValue: oldState, animated: true)
            }
        }
    }
    
    override var isSelected: Bool {
        didSet {
            if oldValue != isSelected {
                var oldState = self.state
                
                if oldValue {
                    oldState.insert(.selected)
                }
                else {
                    oldState.remove(.selected)
                }
                
                self.updateDisplayState(oldValue: oldState, animated: true)
            }
        }
    }
    
    private var t: Double = 0 {
        didSet {
            self.setNeedsDisplay()
            
            if let block = self.tBlock {
                block(self.t, self.snapThreshhold, self.bounds, self.state, self.on)
            }
        }
    }
    
    // MARK: Animation
    
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
    
    // MARK: Touch & Gesture Recognition
    
    private var panGestureRecognizer: SimpleMovementGestureRecognizer!
    private var deepTouchGestureRecognizer: DeepTouchGestureRecognizer!
    
    private var initialTouchPosition: CGPoint?
    private var ignoreGestureRecognizerActions: Bool = false //enabled when we snap into the on position
    
    // MARK: Hardware
    
    private var hapticGenerator: UIImpactFeedbackGenerator!
    
    // MARK: - Lifecycle -
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        if let style = self.tapticStyle {
            self.hapticGenerator = UIImpactFeedbackGenerator(style: style)
        }
        
        self.isOpaque = false
        
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
    
    // MARK: - Actions -
    
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
                let p1 = recognizer.location(in: nil)
                let localPoint = self.convert(p1, from: nil)
                
                self.isHighlighted = pointInsideTapBounds(localPoint)
            }
            
            break
            
        case .ended:
            if let startingConditions = self.tapStartingConditions {
                let p1 = recognizer.location(in: nil)
                let localPoint = self.convert(p1, from: nil)
                
                if pointInsideTapBounds(localPoint) {
                    // this also takes care of animations
                    self.on = !startingConditions.value
                    
                    self.sendActions(for: .valueChanged)
                }
                
                self.tapStartingConditions = nil
            }

            break
            
        case .cancelled:
            fallthrough
        default:
            if let startingConditions = self.tapStartingConditions {
                // this also takes care of animations
                self.on = startingConditions.value
                
                self.tapStartingConditions = nil
            }
            
            break
        }
    }
    
    // TODO: QQQ: this doesn't really belong here
    //            if self.displayState == .toOn, self.tapticStyle != nil {
    //                self.hapticGenerator.prepare()
    //            }
    @objc func action(recognizer: DeepTouchGestureRecognizer) {
//        // ensures sendActions is called when needed; can't do it in displayState didSet b/c on property can also be changed
//        // manually, i.e. we only want it called on user input, which is all handled here
//        func setDisplayState(_ new: State) {
//            let old = self.displayState
//            
//            self.displayState = new
//            
//            if old.isOn != new.isOn {
//                self.sendActions(for: .valueChanged)
//            }
//            
//            if !old.isOn && new.isOn, self.tapticStyle != nil {
//                self.hapticGenerator.impactOccurred()
//            }
//        }
//        
//        if !self.ignoreGestureRecognizerActions {
//            switch recognizer.state {
//                
//            case .began:
//                self.initialTouchPosition = recognizer.location(in: self)
//                
//                switch self.displayState {
//                case .off:
//                    setDisplayState(.toOn)
//                    break
//                case .on:
//                    setDisplayState(.toOff)
//                    break
//                default:
//                    break
//                }
//                
//                fallthrough
//            case .changed:
//                // cancel recognizer if touch strays too far
//                if let p0 = self.initialTouchPosition {
//                    let p1 = recognizer.location(in: self)
//                    let distance = abs(sqrt(pow(Double(p1.x - p0.x), 2) + pow(Double(p1.y - p0.y), 2)))
//                    if distance >= self.cancellationRadius {
//                        recognizer.isEnabled = false
//                        recognizer.isEnabled = true
//                    }
//                }
//                
//                if self.displayState == .toOn {
//                    self.t = recognizer.t
//                }
//                else if self.displayState == .toOff {
//                    self.t = self.snapThreshhold + log10(1 + recognizer.t)
//                }
//                
//                if self.displayState == .toOn {
//                    if self.t >= self.snapThreshhold {
//                        self.ignoreGestureRecognizerActions = true
//                        setDisplayState(.on)
//                    }
//                }
//                
//                break
//                
//            case .ended:
//                fallthrough
//            case .cancelled:
//                if self.displayState.isOn {
//                    setDisplayState(.on)
//                }
//                else {
//                    setDisplayState(.off)
//                }
//                
//                break
//                
//            default:
//                break
//                
//            }
//        }
//        
//        // cancel ignored actions on end of gesture
//        switch recognizer.state {
//            
//        case .ended:
//            fallthrough
//        case .cancelled:
//            fallthrough
//        case .failed:
//            self.ignoreGestureRecognizerActions = false
//            break
//            
//        default:
//            break
//            
//        }
    }
    
    // MARK: - Rendering -
    
    override func draw(_ rect: CGRect) {
        if let block = renderBlock {
            block(self.t, self.snapThreshhold, rect, self.bounds, self.state, self.on)
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
    
    // prevents gesture from eating up scroll view pan
//    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
////        if gestureRecognizer == self.tapGestureRecognizer {
//        if false {
//            return false
//        }
//        else if gestureRecognizer == self.deepTouchGestureRecognizer {
////            if otherGestureRecognizer == self.tapGestureRecognizer {
//            if false {
//                return false
//            }
//            else {
//            // TODO: there's gotta be some better way to do this! we want to make it so that any other gesture causes this one to fail
//                if otherGestureRecognizer.state == .recognized || otherGestureRecognizer.state == .began || otherGestureRecognizer.state == .changed  {
//                    gestureRecognizer.isEnabled = false
//                    gestureRecognizer.isEnabled = true
//                }
//                
//                return true
//            }
//        }
//        
//        return false
//    }

    // MARK: - Helper Classes -
    
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

// MARK: - Tweening Functions -

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
