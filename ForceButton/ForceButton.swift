//
//  ForceButton.swift
//  ForceButton
//
//  Created by Alexei Baboulevitch on 2016-10-5.
//  Copyright © 2016 Alexei Baboulevitch. All rights reserved.
//

import UIKit
import UIKit.UIGestureRecognizerSubclass

// AB: not using .highlighted because highlights are automatic and we need manual control
private extension UIControlState {
    static let depressed: UIControlState = {
        var applicationMask: UIControlState?
        
        var applicationBits = UIControlState.application.rawValue
        for i: UInt in 0..<32 {
            if (applicationBits & 0x1) > 0 {
                applicationMask = UIControlState(rawValue: (UIControlState.application.rawValue & (0x1 << i)))
                break
            }
            applicationBits >>= 1
        }
        
        assert(applicationMask != nil, "could not find any free application mask bits")
        
        return applicationMask!
    }()
}

class ForceButton: UIControl, UIGestureRecognizerDelegate {
    // AB: There are two types of state to track here. First, there's the value state — on or off. This is stored
    // as a separate property and causes the button to change its display state. The second is the display
    // state provided by UIControl. This is what actually corresponds to the visible button state. By default,
    // display state changes are animated.
    
    // MARK: - Properties -
    
    // MARK: Public Custom Properties
    
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
    
    // MARK: Public State Properties
    
    // AB: not my favorite way of doing things, but oh well
    private var disableAutomaticAnimations: Bool = false
    
    var on: Bool = false {
        didSet {
            // KLUDGE: prevents isSelected from overwriting isDepressed; also causes update to be called a few extra times
            let oldState = self.state
            self.isDepressed = false
            self.isSelected = on
            self.updateDisplayState(oldValue: oldState, animated: !self.disableAutomaticAnimations)
        }
    }
    func setOn(_ on: Bool, animated: Bool) {
        self.disableAutomaticAnimations = !animated
        self.on = on
        self.disableAutomaticAnimations = false
        
    }
    
    var isDepressed: Bool = false {
        didSet {
            if oldValue != isDepressed {
                var oldState = self.state
                
                if oldValue {
                    oldState.insert(.depressed)
                }
                else {
                    oldState.remove(.depressed)
                }
                
                self.updateDisplayState(oldValue: oldState, animated: !self.disableAutomaticAnimations)
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
                
                self.updateDisplayState(oldValue: oldState, animated: !self.disableAutomaticAnimations)
            }
        }
    }
    
    // MARK: Appearance Constants, Etc.
    
    // TODO: at the moment we only SORT OF support control state, but it's still good to set up the framework
    private let statesContributingToAppearance: [UIControlState] = [.selected, .depressed]
    private let stateT: [UIControlState:Double] = [
        .normal: 0,                     //off
        .depressed: 0.5,              //off->on highlight
        .selected: 0.4,                 //on
        [.selected, .depressed]: 0.5  //on->off highlight
    ]
    private static let stateTransitionQuick: TimeInterval = 0.3
    private static let stateTransitionLong: TimeInterval = stateTransitionQuick
    private let stateTransitionToDuration: [UIControlState:[UIControlState:TimeInterval]] = [
        .normal: [
            .depressed: stateTransitionQuick,
            .selected: stateTransitionLong
        ],
        .depressed: [
            .normal: stateTransitionQuick,
            .selected: stateTransitionQuick
        ],
        .selected: [
            .normal: stateTransitionLong,
            [.selected, .depressed]: stateTransitionQuick
        ],
        [.selected, .depressed]: [
            .selected: stateTransitionQuick,
            .normal: stateTransitionQuick
        ]
    ]
    private let stateTransitionToTweeningFunction: [UIControlState:[UIControlState:((Double)->Double)]] = [
        .normal: [
//            .depressed: dampenedSine,
            .depressed: easeOutCubic,
            .selected: easeOutCubic
        ],
        .depressed: [
//            .normal: dampenedSine,
            .normal: easeOutCubic,
            .selected: easeOutCubic
        ],
        .selected: [
//            .normal: dampenedSine,
            .normal: easeOutCubic,
            [.selected, .depressed]: easeOutCubic
        ],
        [.selected, .depressed]: [
            .selected: easeOutCubic,
            .normal: easeOutCubic
//            .normal: dampenedSine
        ]
    ]
    
    private let snapOnT: Double = 0.4
    private let snapOffT: Double = 0.5
//    private let cancellationThreshhold: CGFloat = 16
    private let cancellationThreshhold: CGFloat = 100
    
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
        
        if oldValue == newValue {
            return
        }
        
        //print("\(self.hashValue): going from state \(oldValue.description) to state \(newValue.description)")
        
        guard let targetT: Double = self.stateT[newValue] else {
            assert(false, "unable to handle state transition from \(oldValue.description) to \(newValue.description)")
            return
        }
        
        // cancel existing animations
        self.animation = nil
        
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
    
    private var t: Double = 0 {
        didSet {
            self.setNeedsDisplay()
            
            if let block = self.tBlock {
                block(self.t, self.snapOnT, self.bounds, self.state, self.on)
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
    
    // MARK: Hardware
    
    private var hapticGenerator: UIImpactFeedbackGenerator!
    private var lightHapticGenerator: UIImpactFeedbackGenerator!
    
    // MARK: - Lifecycle -
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        if let style = self.tapticStyle {
            self.hapticGenerator = UIImpactFeedbackGenerator(style: style)
            self.lightHapticGenerator = UIImpactFeedbackGenerator(style: .light)
        }
        
        self.isOpaque = false
        
        self.panGestureRecognizer = SimpleMovementGestureRecognizer(target: self, action: #selector(tapEvents(recognizer:)))
        self.panGestureRecognizer.delegate = self
        self.addGestureRecognizer(self.panGestureRecognizer)
        
        self.deepTouchGestureRecognizer = DeepTouchGestureRecognizer(target: self, action: #selector(deepTouchEvents(recognizer:)))
        self.deepTouchGestureRecognizer.delegate = self
        self.addGestureRecognizer(self.deepTouchGestureRecognizer)
        
        self.deepTouchGestureRecognizer.nonForceDefaultValue = self.snapOnT
        self.deepTouchGestureRecognizer.forceScaleFactor = 1.25
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
    
    // TODO: should deepTouchStartingConditions and tapStartingConditions really be different variables?
    private var tapStartingConditions: (position: CGPoint, time: TimeInterval, value: Bool)?
    private var deepTouchStartingConditions: (position: CGPoint, time: TimeInterval, value: Bool)?
    
    private func pointInsideTapBounds(_ p: CGPoint) -> Bool {
        return !(p.x >= self.bounds.size.width + cancellationThreshhold ||
            p.x <= -cancellationThreshhold ||
            p.y >= self.bounds.size.height + cancellationThreshhold ||
            p.y <= -cancellationThreshhold)
    }
    
    @objc private func tapEvents(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
            
        case .began:
            print("tap gesture recognizer began")
            self.animation = nil
            
            fallthrough
        case .changed:
            if self.tapStartingConditions == nil {
                self.tapStartingConditions = (position: recognizer.location(in: nil), time: CACurrentMediaTime(), value: self.on)
            }
            
            if let startingConditions = self.tapStartingConditions {
                let p1 = recognizer.location(in: nil)
                let localPoint = self.convert(p1, from: nil)
                
                self.isDepressed = pointInsideTapBounds(localPoint)
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
            print("tap gesture recognizer cancelled")
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

    // NEXT: display state custom for manual t
    @objc private func deepTouchEvents(recognizer: DeepTouchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            print("deep touch recognition began")
            self.panGestureRecognizer.cancel() //TODO: move this elsewhere?
            self.animation = nil
            
            fallthrough
        case .changed:
            if self.deepTouchStartingConditions == nil {
                self.deepTouchStartingConditions = (position: recognizer.location(in: nil), time: CACurrentMediaTime(), value: self.on)
            }
            
            if let startingConditions = self.deepTouchStartingConditions {
                let p1 = recognizer.location(in: nil)
                let localPoint = self.convert(p1, from: nil)
                
                // TODO: cancellation
                
                if startingConditions.value {
                    if self.on {
                        self.lightHapticGenerator.prepare()
                        
                        if self.t >= self.snapOffT {
                            self.setOn(false, animated: false)
                            
                            self.lightHapticGenerator.impactOccurred()
                            
                            self.sendActions(for: .valueChanged)
                        }
                        
                        self.t = self.snapOnT + log10(1 + recognizer.t)
                    }
                    else {
                        self.t = self.snapOnT + log10(1 + recognizer.t)
                    }
                }
                else {
                    if self.on {
                        // ignore -- incidentally, this also prevents interference with the animation
                    }
                    else {
                        self.hapticGenerator.prepare()
                        
                        self.t = recognizer.t
                        
                        if self.t >= self.snapOnT {
                            self.on = true
                            
                            self.hapticGenerator.impactOccurred()
                            
                            self.sendActions(for: .valueChanged)
                        }
                    }
                }
            }
        case .ended:
            if let startingConditions = self.deepTouchStartingConditions {
                // AB: mostly for off state
                // TODO: depressed??
                var oldState = self.state
                if startingConditions.value {
                    oldState.insert(.selected)
                }
                else {
                    oldState.remove(.selected)
                }
                updateDisplayState(oldValue: oldState, animated: true)
                
                self.deepTouchStartingConditions = nil
            }
            
            break
        case .cancelled:
            print("deep touch gesture recognizer cancelled")
            fallthrough
        default:
            if let startingConditions = self.deepTouchStartingConditions {
                self.on = startingConditions.value
                
                self.deepTouchStartingConditions = nil
            }
        }
    }
    
    // MARK: - Rendering -
    
    override func draw(_ rect: CGRect) {
        if let block = renderBlock {
            block(self.t, self.snapOnT, rect, self.bounds, self.state, self.on)
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
    
    // MARK: - Gesture Recognizers -
    
    // NEXT: figure out a way to cancel simple pan as soon as any other gesture recognizer is begun
    // prevents gesture from eating up scroll view pan
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
//        print("other gesture recognizer: \(type(of:otherGestureRecognizer)) w/state \(otherGestureRecognizer.state.rawValue)")
        
        if gestureRecognizer == self.panGestureRecognizer {
            switch otherGestureRecognizer.state {
            case .began:
                fallthrough
            case .changed:
                gestureRecognizer.cancel()
                return true
                
            case .possible:
                fallthrough
            case .ended:
                fallthrough
            case .cancelled:
                fallthrough
            case .failed:
                return true
            }
        }
        
        else if gestureRecognizer == self.deepTouchGestureRecognizer {
            switch otherGestureRecognizer.state {
            case .began:
                fallthrough
            case .changed:
                if otherGestureRecognizer != self.panGestureRecognizer {
                    gestureRecognizer.cancel()
                }
                return true
                
            case .possible:
                fallthrough
            case .ended:
                fallthrough
            case .cancelled:
                fallthrough
            case .failed:
                return true
            }
        }
        
//        if gestureRecognizer == self.panGestureRecognizer {
//            self.panGestureRecognizer.isEnabled = false
//            self.panGestureRecognizer.isEnabled = true
//        }
        
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
        return true
    }

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
            
            if self.firstTouch != nil {
                for touch in touches {
                    if touch != self.firstTouch {
                        self.ignore(touch, for: event)
                    }
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
        var forceScaleFactor: Double = 1
        
        private(set) var t: Double = 0
        
        private var firstTouch: UITouch?
        
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
            
            if self.firstTouch != nil {
                for touch in touches {
                    if touch != self.firstTouch {
                        self.ignore(touch, for: event)
                    }
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

// MARK: -

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
