//
//  ForceButton.swift
//  ForceButton
//
//  Created by Alexei Baboulevitch on 2016-10-5.
//  Copyright © 2016 Alexei Baboulevitch. All rights reserved.
//

import UIKit
import UIKit.UIGestureRecognizerSubclass

// TWO TASKS:
//  a) pop-up menu on force touch
//  b) combined notes on adjascent touch

class ForceButton: UIControl, UIGestureRecognizerDelegate {
    // AB: There are two types of state to track here. First, there's the value state — on or off. This is stored
    // as a separate property and causes the button to change its display state. The second is the display
    // state provided by UIControl. This is what actually corresponds to the visible button state. By default,
    // display state changes are animated.
    
    static let StandardTapForce: Double = 0.18 //0.15 according to Apple docs, but 0.18 works slightly better for this case
    
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
    // TODO: internal/private
    internal var disableAutomaticAnimations: Bool = false
    
    var on: Bool = false {
        didSet {
            // KLUDGE: prevents isSelected from overwriting isDepressed; also causes update to be called a few extra times
            let oldState = self.state
            let oldT = self.t
            
            let previousDisabledAnimations = self.disableAutomaticAnimations
            self.disableAutomaticAnimations = true
            self.isDepressed = false
            self.isSelected = on
            self.disableAutomaticAnimations = previousDisabledAnimations
            
            self.updateDisplayState(oldValue: oldState, oldT: oldT, animated: !self.disableAutomaticAnimations)
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
                updateDisplayState(settingSubState: .depressed, toOn: isDepressed)
            }
        }
    }
    
    override var isSelected: Bool {
        didSet {
            if oldValue != isSelected {
                updateDisplayState(settingSubState: .selected, toOn: isSelected)
            }
        }
    }
    
    // MARK: Appearance Constants, Etc.
    
    // AB: If you wish to add more t-based states, simply override statesContributingToAppearance and t(forState:).
    // The duration and tweening function overrides are optional. You don't have to override the state property;
    // statesContributingToAppearance takes care of that for you.
    
    override var state: UIControlState {
        get {
            var previous = super.state
            
            for (state, selector) in self.statesContributingToAppearance {
                // AB: http://stackoverflow.com/a/35073628/89812
                if let _ = self.perform(selector) {
                    previous.insert(state)
                }
            }
            
            return previous
        }
    }
    
    // override point for custom states
    var statesContributingToAppearance: [UIControlState:Selector] {
        get {
            return [
                UIControlState.selected: #selector(getter:isSelected),
                UIControlState.depressed: #selector(getter:isDepressed)
            ]
        }
    }
    
    // override point for custom states
    func t(forState state: UIControlState) -> Double? {
        // AB: it's hard to go from deep highlights to 3d touch convincingly, so we decrease the highlights in 3d touch mode
        let is3dTouchEnabled = (self.traitCollection.forceTouchCapability == .available)

        if state == .normal {
            return 0
        }
        else if state == .depressed {
            return (is3dTouchEnabled ? 0.1 : 0.25)
        }
        else if state == .selected {
            return 0.4
        }
        else if state == [.selected, .depressed] {
            return (is3dTouchEnabled ? 0.5 : 0.6)
        }
        
        return nil
    }
    
    // optional override point for custom states
    func duration(fromState: UIControlState, toState: UIControlState) -> TimeInterval {
        return builtInStateTransitionToDuration[fromState]?[toState] ?? 0.1
    }
    private var builtInStateTransitionToDuration: [UIControlState:[UIControlState:TimeInterval]] {
        get {
            let quick: TimeInterval = 0.1
            let cancel = quick
            let long: TimeInterval = 0.2
            let bouncy: TimeInterval = 0.4
            
            return [
                .normal: [
                    .depressed: quick,
                    .selected: bouncy
                ],
                .depressed: [
                    .normal: cancel,
                    .selected: 0.05
                ],
                .selected: [
                    .normal: long,
                    [.selected, .depressed]: cancel
                ],
                [.selected, .depressed]: [
                    .selected: cancel,
                    .normal: long
                ]
            ]
        }
    }
    
    // optional override point for custom states
    func tweeningFunction(fromState: UIControlState, toState: UIControlState) -> ((Double)->Double) {
        return easeOutCubic
    }
    
    // optional override point for custom states
    func additiveFunction(fromState: UIControlState, toState: UIControlState) -> ((Double)->Double)? {
        // TODO: move to subclass
        if fromState == .normal {
            if toState == .selected {
                return dampenedSine
            }
        }
        
        return nil
    }
    
    private let snapOnT: Double = 0.4
    private let snapOffT: Double = 0.5
    private let cancellationThreshhold: CGFloat = 16
    
    // MARK: Display State
    
    func updateDisplayState(settingSubState subState: UIControlState, toOn on: Bool, forced: Bool = false) {
        var oldState = self.state
        
        if on {
            oldState.remove(subState)
        }
        else {
            oldState.insert(subState)
        }
        
        self.updateDisplayState(oldValue: oldState, oldT: self.t, animated: !self.disableAutomaticAnimations, forced: forced)
    }
    
    // TODO: internal
    internal func updateDisplayState(oldValue: UIControlState, oldT: Double, animated: Bool, forced: Bool = false) {
        func debugStateBits(_ state: UIControlState) -> String {
            var string = ""
            
            if state.contains(.depressed) {
                string += "d"
            }
            if state.contains(.selected) {
                string += "s"
            }
            if state.contains(UIControlState.customMask(n: 2)) {
                string += "h"
            }
            
            return "["+string+"]"
        }
        
        // AB: only some of the UIControl states affect appearance
        func condenseState(_ state: UIControlState) -> UIControlState {
            var returnState: UIControlState = .normal
            for substate in self.statesContributingToAppearance.keys {
                if state.contains(substate) {
                    returnState.insert(substate)
                }
            }
            return returnState
        }
        
        let oldValue = condenseState(oldValue)
        let newValue = condenseState(self.state)
        
        // when is forced applicable? when we're not animating but are off with our t and want to animate it
        if !forced && oldValue == newValue {
            return
        }
        
        //print("updating display state from \(debugStateBits(oldValue))/\(oldT) -> \(debugStateBits(newValue))")
        
        let baseT: Double = oldT
        guard
            let targetT: Double = t(forState: newValue)
            else {
            assert(false, "unable to handle state transition from \(oldValue.rawValue) to \(newValue.rawValue)")
            return
        }
        
        // cancel existing animations
        self.animation = nil
        
        if animated {
            let tweeningFunction = self.tweeningFunction(fromState: oldValue, toState: newValue)
            let additiveFunction = self.additiveFunction(fromState: oldValue, toState: newValue)
            let duration = self.duration(fromState: oldValue, toState: newValue)
            
            //print("animating from \(debugStateBits(oldValue)) to \(debugStateBits(self.state)) with duration \(duration)")
            
            self.animation = (
                delay: 0,
                start: baseT,
                end: targetT,
                startTime: TimeInterval(CFAbsoluteTimeGetCurrent()),
                duration: duration,
                function: tweeningFunction,
                additiveFunction: additiveFunction
            )
        }
        else {
            self.t = targetT
        }
    }
    
    // AB: suggested that this not be touched from the outside, as animations/state will interfere
    var t: Double = 0 {
        didSet {
            self.setNeedsDisplay()
            
            if let block = self.tBlock {
                block(self.t, self.snapOnT, self.bounds, self.state, self.on)
            }
        }
    }
    
    // MARK: Animation
    
    private var animationDisplayLink: CADisplayLink?
    private var animation: (delay: Double, start: Double, end: Double, startTime: TimeInterval, duration: TimeInterval, function: ((Double)->Double), additiveFunction:((Double)->Double)?)? {
        didSet {
            if let displayLink = self.animationDisplayLink {
                DebuggingDeregisterDisplayLink()
                displayLink.invalidate()
                self.animationDisplayLink = nil
            }
            
            if let animation = self.animation {
                self.t = animation.start
                
                let animationDisplayLink = CADisplayLink.init(target: self, selector: #selector(animation(displayLink:)))
                DebuggingRegisterDisplayLink()
                animationDisplayLink.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
                self.animationDisplayLink = animationDisplayLink
            }
        }
    }
    
    // MARK: Touch & Gesture Recognition
    
    private var panGestureRecognizer: SimpleMovementGestureRecognizer!
    private var deepTouchGestureRecognizer: DeepTouchGestureRecognizer!
    var is3dTouching: Bool {
        get {
            if deepTouchGestureRecognizer.isEnabled {
                switch deepTouchGestureRecognizer.state {
                case .began:
                    fallthrough
                case .changed:
                    return true
                    
                case .cancelled:
                    fallthrough
                case .ended:
                    fallthrough
                case .failed:
                    fallthrough
                case .possible:
                    return false
                }
            }
            else {
                return false
            }
        }
    }
    
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
    
    func cancelTouches() {
        self.panGestureRecognizer.cancel()
        self.deepTouchGestureRecognizer.cancel()
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
            
            if let _  = self.tapStartingConditions {
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
        case .failed:
            print("tap gesture recognizer failed")
            fallthrough
        default:
            // TOOD: cancellation animation
            if let startingConditions = self.tapStartingConditions {
                // this also takes care of animations
                if self.on != startingConditions.value {
                    self.on = startingConditions.value
                    
                    self.sendActions(for: .valueChanged)
                }
                
                self.tapStartingConditions = nil
            }
            
            // TODO: move
            self.isDepressed = false
            
            break
        }
    }

    @objc private func deepTouchEvents(recognizer: DeepTouchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            print("deep touch recognition began")
            self.panGestureRecognizer.cancel() //TODO: move this elsewhere? NEXT:
            self.animation = nil
            
            fallthrough
        case .changed:
            if self.deepTouchStartingConditions == nil {
                self.deepTouchStartingConditions = (position: recognizer.location(in: nil), time: CACurrentMediaTime(), value: self.on)
            }
            
            if let startingConditions = self.deepTouchStartingConditions {
                //let p1 = recognizer.location(in: nil)
                //let localPoint = self.convert(p1, from: nil)
                
                let normalizedT = min(max((recognizer.t - recognizer.minimumForce) / (1 - recognizer.minimumForce), 0), 1)
                
                if startingConditions.value {
                    if self.on {
                        self.lightHapticGenerator.prepare()
                        
                        if self.t >= self.snapOffT {
                            self.setOn(false, animated: false)
                            
                            self.lightHapticGenerator.impactOccurred()
                            
                            self.sendActions(for: .valueChanged)
                        }
                        
                        self.t = self.snapOnT + log10(1 + normalizedT)
                    }
                    else {
                        self.t = self.snapOnT + log10(1 + normalizedT)
                    }
                }
                else {
                    if self.on {
                        // ignore -- incidentally, this also prevents interference with the animation
                    }
                    else {
                        self.hapticGenerator.prepare()
                        
                        self.t = normalizedT
                        
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
                // AB: force animation if we're on the wrong t, even if the state is correct; happens on 'off'
                // KLUDGE: we don't do this on 'on' b/c 'on' starts ignoring the gesture after triggering
                if !self.on && self.t != t(forState: self.state) {
                    let value: Bool = startingConditions.value
                    let oldState: UIControlState = (value ? UIControlState.selected : UIControlState.normal)
                    updateDisplayState(oldValue: oldState, oldT: self.t, animated: true, forced: true)
                }
                
                self.deepTouchStartingConditions = nil
            }
            
            break
        case .cancelled:
            print("deep touch gesture recognizer cancelled")
            fallthrough
        default:
            if let startingConditions = self.deepTouchStartingConditions {
                if self.on != startingConditions.value {
                    self.on = startingConditions.value
                    
                    self.sendActions(for: .valueChanged)
                }
                else {
                    // TODO: make sure this is actually correct -- fake state to ensure animation; prolly need something else,
                    // like animation for going from same state to same state
                    self.disableAutomaticAnimations = true
                    let oldState: UIControlState
                    let oldT = self.t
                    stateStuff: do {
                        self.isSelected = !startingConditions.value
                        oldState = self.state
                        
                        self.isSelected = startingConditions.value
                        self.isDepressed = false
                    }
                    self.disableAutomaticAnimations = false
                    
                    updateDisplayState(oldValue: oldState, oldT: oldT, animated: true)
                }
                
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
            if let displayLink = self.animationDisplayLink {
                DebuggingDeregisterDisplayLink()
                displayLink.invalidate()
                self.animationDisplayLink = nil
            }
            
            return
        }
        
        let actualStartTime = animation.startTime + animation.delay
        let time = TimeInterval(CFAbsoluteTimeGetCurrent())
        let t = max(min(Double((time - actualStartTime) / animation.duration), 1), 0)
        let actualT = animation.function(t)
        let additiveT: Double
        if let additiveFunction = animation.additiveFunction {
            additiveT = additiveFunction(t)
        }
        else {
            additiveT = 0
        }
        let value = animation.start + actualT * (animation.end - animation.start)
        //print("\(displayLink.hashValue): \(t) -> \(actualT) (\(value + additiveT))")
        
        self.t = value + additiveT
        
        if t >= 1 {
            self.animation = nil
            
            if let displayLink = self.animationDisplayLink {
                DebuggingDeregisterDisplayLink()
                displayLink.invalidate()
                self.animationDisplayLink = nil
            }
        }
    }
    
    // MARK: - Gesture Recognizers -
    
    // NEXT: figure out a way to cancel simple pan as soon as any other gesture recognizer is begun
    // AB: why cancel? both our tap and deep touch recognizers begin pretty much immediately (for feedback re: button
    // state) and so nothing can really prevent them
    // prevents gesture from eating up scroll view pan
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
//        print("other gesture recognizer: \(type(of:otherGestureRecognizer)) w/state \(otherGestureRecognizer.state.rawValue)")
        
        if gestureRecognizer == self.panGestureRecognizer {
            switch otherGestureRecognizer.state {
            case .began:
                fallthrough
            case .changed:
                if otherGestureRecognizer.canPrevent(gestureRecognizer) {
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
        
        else if gestureRecognizer == self.deepTouchGestureRecognizer {
            switch otherGestureRecognizer.state {
            case .began:
                fallthrough
            case .changed:
                if otherGestureRecognizer != self.panGestureRecognizer && otherGestureRecognizer.canPrevent(gestureRecognizer) {
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
        var minimumForce: Double = ForceButton.StandardTapForce //standard-ish tap
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

// MARK: - Helpers -

// MARK: Extensions

fileprivate extension UIControlState {
    static func customMask(n: Int) -> UIControlState {
        var applicationMask: UIControlState?
        
        var applicationBits = UIControlState.application.rawValue
        var foundBits = 0
        for i: UInt in 0..<32 {
            if (applicationBits & 0x1) > 0 {
                if foundBits == n {
                    applicationMask = UIControlState(rawValue: (UIControlState.application.rawValue & (0x1 << i)))
                    break
                }
                foundBits += 1
            }
            applicationBits >>= 1
        }
        
        assert(applicationMask != nil, "could not find any free application mask bits")
        
        return applicationMask!
    }
}

// AB: not using .highlighted because highlights are automatic and we need manual control
extension UIControlState {
    //static let manualControl: UIControlState = {
    //    return UIControlState.customMask(n: 0)
    //}()
    static let depressed: UIControlState = {
        return UIControlState.customMask(n: 1)
    }()
}

extension UIControlState: Hashable {
    public var hashValue: Int {
        get {
            return self.rawValue.hashValue
        }
    }
}

fileprivate extension UIGestureRecognizer {
    func cancel() {
        let wasEnabled = self.isEnabled
        self.isEnabled = false
        self.isEnabled = wasEnabled
    }
}

// MARK: Easing Functions

fileprivate func easeOutCubic(_ t: Double) -> Double {
    return max(min(1 - pow(1 - t, 3), 1), 0)
}

fileprivate func dampenedSine(_ t: Double) -> Double {
    let initialAmplitude: Double = 0.5
    let decayConstant: Double = 4.5
    let numberOfBounces: Double = 2
    let angularFrequency: Double = 2 * Double.pi * numberOfBounces
    
    let returnT = initialAmplitude * pow(M_E, -decayConstant * t) * sin(angularFrequency * t)
    
    return returnT
}

// MARK: Debugging

// AB: these aren't terribly useful for general use, but I use them in another project so they're stayin' in

fileprivate let DebuggingPrintMessages: Bool = false

fileprivate let DebuggingPrintInterval: TimeInterval = 0.5
fileprivate var DebuggingDisplayLinks = 0
fileprivate var DebuggingLastPrint: TimeInterval = 0

func DebuggingRegisterDisplayLink(_ print: Bool = true) {
    DebuggingDisplayLinks += 1
    
    if print {
        DebuggingPrint()
    }
}

fileprivate func DebuggingDeregisterDisplayLink(_ print: Bool = true) {
    DebuggingDisplayLinks -= 1
    
    if print {
        DebuggingPrint()
    }
}

fileprivate func DebuggingPrint() {
    let time = CACurrentMediaTime()
    
    var shouldPrint: Bool
    
    if DebuggingLastPrint == 0 {
        shouldPrint = true
    }
    else {
        let delta = time - DebuggingLastPrint
        
        if delta > DebuggingPrintInterval {
            shouldPrint = true
        }
        else {
            shouldPrint = false
        }
    }
    
    shouldPrint = (DebuggingPrintMessages ? shouldPrint : false)
    
    if shouldPrint {
        print("\n")
        print("――――――――DEBUG――――――――")
        print("‣ FB Display Links: \(DebuggingDisplayLinks)")
        print("―――――――――――――――――――――")
        
        DebuggingLastPrint = time
    }
}
