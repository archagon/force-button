//
//  ForceButton.swift
//  ForceButton
//
//  Created by Alexei Baboulevitch on 2016-10-5.
//  Copyright © 2016 Alexei Baboulevitch. All rights reserved.
//

import UIKit
import UIKit.UIGestureRecognizerSubclass

// TODO: pressure should check within radius
// TODO: figure out how to make manual-t play nice with animations and with state

// a parametric button with (optional) pressure control and state animations
open class ForceButton: UIControl, UIGestureRecognizerDelegate {
    // AB: There are two types of state to track here. First, there's the value state — on or off. This is stored
    // as a separate property and causes the button to change its display state. The second is the state property
    // provided by UIControl. This is what actually corresponds to the visible button state. By default,
    // display state changes are animated. The state is computed from a number of 'isX' properties, and as such,
    // the way a button looks at a given moment might not necessarily map to its under-the-hood state. (But an update 
    // can be triggered to animate it back to consistency.)
    
    public static let StandardTapForce: Double = 0.2 //0.15 according to Apple docs, but works slightly better for this case
    
    // MARK: Public Custom Properties
    
    public var tapticStyle: UIImpactFeedbackStyle? = .medium {
        didSet {
            if let style = tapticStyle {
                self.hapticGenerator = UIImpactFeedbackGenerator(style: style)
            }
        }
    }
    
    public var supportsPressure: Bool = true {
        didSet {
            cancel()
            traitCollectionDidChange(self.traitCollection)
        }
    }
    
    // parametric button rendering
    public var renderBlock: ((_ t: Double, _ threshhold: Double, _ rect: CGRect, _ bounds: CGRect, _ state: UIControlState, _ value: Bool)->())? {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    // for non-rendering behaviors nevertheless tied to t
    public var tBlock: ((_ t: Double, _ threshhold: Double, _ bounds: CGRect, _ state: UIControlState, _ value: Bool)->())?
    
    // MARK: Public State Properties
    
    // NOTE: as with UISwitch, this only emits valueChanged event if triggered by user, not programmatically
    public var isOn: Bool = false {
        didSet {
            updateDisplayStateBatch {
                self.isDepressed = false
                self.isSelected = isOn
            }
        }
    }
    public func setOn(_ on: Bool, animated: Bool) {
        performAnimableChanges(animated: animated) { (animated: Bool) in
            self.isOn = on
        }
    }
    
    // NOTE: the 'isX' properties are definitive, while the 'state' property is derived from them!
    
    public var isDepressed: Bool = false {
        didSet {
            updateDisplayState(settingSubState: .depressed, from: oldValue)
        }
    }
    
    override open var isSelected: Bool {
        didSet {
            updateDisplayState(settingSubState: .selected, from: oldValue)
        }
    }
    
    // for subclassers: setting various properties automatically animates the button, so we need this override
    // TODO: seems like this should persist, if nested...? mostly it works b/c important calls are implicitly animated (or not)
    public func performAnimableChanges(animated: Bool, _ function: (Bool)->()) {
        let previousDisabledAnimations = self._disableAutomaticAnimations
        self._disableAutomaticAnimations = !animated
        function(animated)
        self._disableAutomaticAnimations = previousDisabledAnimations
    }
    private var _disableAutomaticAnimations: Bool = false //should not be touched by anything other than the above method
    public var disableAutomaticAnimations: Bool { return _disableAutomaticAnimations }
    
    // MARK: Appearance Constants, Etc.
    
    // AB: If you wish to add more t-based states, simply override statesContributingToAppearance and t(forState:).
    // The duration and tweening function overrides are optional. You don't have to override the state property;
    // statesContributingToAppearance takes care of that for you.
    
    override open var state: UIControlState {
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
    open var statesContributingToAppearance: [UIControlState:Selector] {
        get {
            return [
                UIControlState.selected: #selector(getter:isSelected),
                UIControlState.depressed: #selector(getter:isDepressed)
            ]
        }
    }
    
    // override point for custom states
    open func t(forState state: UIControlState) -> Double? {
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
    open func duration(fromState: UIControlState, toState: UIControlState) -> TimeInterval {
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
    open func tweeningFunction(fromState: UIControlState, toState: UIControlState) -> ((Double)->Double) {
        return easeOutCubic
    }
    
    // optional override point for custom states
    open func additiveFunction(fromState: UIControlState, toState: UIControlState) -> ((Double)->Double)? {
        // TODO: move to subclass
        if fromState == .normal {
            if toState == .selected {
                return dampenedSine
            }
        }
        
        return nil
    }
    
    // MARK: Display State
    
    // for subclass use
    public func updateDisplayStateBatch(_ block: ()->()) {
        func getAccumulatedState() -> (counter: Int, startingState: UIControlState, startingT: Double, forced: Bool) {
            guard let accumulatedState = _updateDisplayStateBatchAccumulatedState else {
                assert(false)
                return (0, [], 0, false)
            }
            
            assert(accumulatedState.counter >= 0)
            
            return accumulatedState
        }
        
        if _updateDisplayStateBatchAccumulatedState == nil {
            _updateDisplayStateBatchAccumulatedState = (0, self.state, self.t, false)
        }
        
        var accumulatedState = getAccumulatedState()
        accumulatedState.counter += 1
        self._updateDisplayStateBatchAccumulatedState = accumulatedState
        
        block()
        
        accumulatedState = getAccumulatedState()
        accumulatedState.counter -= 1
        self._updateDisplayStateBatchAccumulatedState = accumulatedState
        
        if accumulatedState.counter == 0 {
            self.updateDisplayState(oldValue: accumulatedState.startingState, newValue: self.state, oldT: accumulatedState.startingT, animated: !self.disableAutomaticAnimations, forced: accumulatedState.forced)
            _updateDisplayStateBatchAccumulatedState = nil
        }
    }
    public func updateDisplayState(settingSubState subState: UIControlState, from: Bool, forced: Bool = false) {
        if var accumulatedState = _updateDisplayStateBatchAccumulatedState {
            // batching, so accumulate and defer animation
            
            accumulatedState.forced = (accumulatedState.forced || forced)
            
            _updateDisplayStateBatchAccumulatedState = accumulatedState
        }
        else {
            // not batching, so run update animation right away
            
            var oldState = self.state
            
            if from {
                oldState.insert(subState)
            }
            else {
                oldState.remove(subState)
            }
            
            self.updateDisplayState(oldValue: oldState, newValue: self.state, oldT: self.t, animated: !self.disableAutomaticAnimations, forced: forced)
        }
    }
    private var _updateDisplayStateBatchAccumulatedState: (counter: Int, startingState: UIControlState, startingT: Double, forced: Bool)? //should not be touched outside the above two methods
    
    // for subclass use
    public func updateDisplayState(oldValue: UIControlState, newValue: UIControlState, oldT: Double, animated: Bool, forced: Bool = false) {
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
        let newValue = condenseState(newValue)
        
        // when is forced applicable? when we're not animating but are off with our t and want to animate it
        if !forced && oldValue == newValue {
            return
        }
        
        //print("updating display state from \(debugStateBits(oldValue))->\(debugStateBits(newValue)) (\(oldT))")
        
        let baseT: Double = oldT
        guard let targetT: Double = t(forState: newValue) else {
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
    public var t: Double = 0 {
        didSet {
            self.setNeedsDisplay()
            
            if let block = self.tBlock {
                block(self.t, self.snapOnT, self.bounds, self.state, self.isOn)
            }
        }
    }
    
    // MARK: Animation
    
    // TODO: replace with Animation object
    private var animationDisplayLink: CADisplayLink?
    private var animation: (delay: Double, start: Double, end: Double, startTime: TimeInterval, duration: TimeInterval, function: ((Double)->Double), additiveFunction:((Double)->Double)?)? {
        didSet {
            if let displayLink = self.animationDisplayLink {
                DebugCounter.counter.decrement(ForceButton.DebugDisplayLinksIdentifier)
                displayLink.invalidate()
                self.animationDisplayLink = nil
            }
            
            if let animation = self.animation {
                self.t = animation.start
                
                let animationDisplayLink = CADisplayLink.init(target: self, selector: #selector(animation(displayLink:)))
                DebugCounter.counter.increment(ForceButton.DebugDisplayLinksIdentifier)
                animationDisplayLink.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
                self.animationDisplayLink = animationDisplayLink
            }
        }
    }
    
    // MARK: Touch & Gesture Recognition
    
    private var regularTouchGestureRecognizer: SimpleMovementGestureRecognizer!
    private var deepTouchGestureRecognizer: SimpleDeepTouchGestureRecognizer!
    
    private var is3dTouching: Bool {
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
    
    public let snapOnT: Double = 0.4
    public let snapOffT: Double = 0.5
    public let cancellationThreshhold: CGFloat = 16
    
    // MARK: Hardware
    
    private var hapticGenerator: UIImpactFeedbackGenerator!
    private var lightHapticGenerator: UIImpactFeedbackGenerator!
    
    // MARK: Lifecycle
    
    deinit {
        DebugCounter.counter.decrement(ForceButton.DebugForceButtonsIdentifier)
    }
    
    override public init(frame: CGRect) {
        DebugCounter.counter.increment(ForceButton.DebugForceButtonsIdentifier)
        
        super.init(frame: frame)
        
        if let style = self.tapticStyle {
            self.hapticGenerator = UIImpactFeedbackGenerator(style: style)
            self.lightHapticGenerator = UIImpactFeedbackGenerator(style: .light)
        }
        
        self.isOpaque = false
        
        self.regularTouchGestureRecognizer = SimpleMovementGestureRecognizer(target: self, action: #selector(tapEvents(recognizer:)))
        self.regularTouchGestureRecognizer.delegate = self
        self.addGestureRecognizer(self.regularTouchGestureRecognizer)
        
        self.deepTouchGestureRecognizer = SimpleDeepTouchGestureRecognizer(target: self, action: #selector(deepTouchEvents(recognizer:)))
        self.deepTouchGestureRecognizer.delegate = self
        self.addGestureRecognizer(self.deepTouchGestureRecognizer)
        
        self.deepTouchGestureRecognizer.nonForceDefaultValue = self.snapOnT
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if self.traitCollection.forceTouchCapability == .unavailable {
            self.deepTouchGestureRecognizer.isEnabled = false
        }
        else if self.traitCollection.forceTouchCapability == .available {
            self.deepTouchGestureRecognizer.isEnabled = self.supportsPressure
        }
        // and do nothing on 'unknown'
    }
    
    public func cancel() {
        self.regularTouchGestureRecognizer.cancel()
        self.deepTouchGestureRecognizer.cancel()
    }
    
    // MARK: Gestures
    
    private func pointInsideTapBounds(_ p: CGPoint) -> Bool {
        return !(p.x >= self.bounds.size.width + cancellationThreshhold ||
            p.x <= -cancellationThreshhold ||
            p.y >= self.bounds.size.height + cancellationThreshhold ||
            p.y <= -cancellationThreshhold)
    }
    
    override open func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == self.regularTouchGestureRecognizer {
            // if we're in deep touch mode and another finger comes in, make sure it can't start another pan gesture
            if self.is3dTouching {
                return false
            }
        }
        
        return true
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if (gestureRecognizer == self.regularTouchGestureRecognizer || otherGestureRecognizer == self.regularTouchGestureRecognizer) {
            // can't return to regular ol' touch from deep touch
            return !self.deepTouchMode
        }
        else {
            // since both gesture recognizers are "sensors" that are immediately recognized (basically), this prevents lock up with e.g. scroll views
            return true
        }
    }
    
    // TODO: should deepTouchStartingConditions and tapStartingConditions really be different variables?
    // these should only be modified by the below gesture recognizer actions
    private var _tapStartingConditions: (position: CGPoint, time: TimeInterval, value: Bool)?
    private var _deepTouchStartingConditions: (position: CGPoint, time: TimeInterval, value: Bool)?
    private var deepTouchMode: Bool {
        return _deepTouchStartingConditions != nil
    }
    
    // handles non-deep-touch taps, highlights, etc. (i.e. standard UIButton behavior)
    @objc private func tapEvents(recognizer: SimpleMovementGestureRecognizer) {
        switch recognizer.state {
        case .began:
            //print("tap gesture recognizer began")
            
            self.animation = nil
            
            fallthrough
        case .changed:
            if self._tapStartingConditions == nil {
                self._tapStartingConditions = (position: recognizer.location(in: nil), time: CACurrentMediaTime(), value: self.isOn)
            }
            
            if let _  = self._tapStartingConditions {
                let p1 = recognizer.location(in: nil)
                let localPoint = self.convert(p1, from: nil)
                
                self.isDepressed = pointInsideTapBounds(localPoint)
            }
            
            break
        case .ended:
            //print("tap gesture recognizer ended")
            
            if let startingConditions = self._tapStartingConditions {
                let p1 = recognizer.location(in: nil)
                let localPoint = self.convert(p1, from: nil)
                
                if pointInsideTapBounds(localPoint) {
                    // this also takes care of animations
                    self.isOn = !startingConditions.value
                    self.sendActions(for: .valueChanged)
                }
                
                self._tapStartingConditions = nil
            }

            break
        case .cancelled:
            //print("tap gesture recognizer cancelled")
            
            fallthrough
        default:
            if let startingConditions = self._tapStartingConditions {
                let currentOn = self.isOn
                let originalOn = startingConditions.value
                
                // this also takes care of animations and state changes
                self.isOn = originalOn
                if currentOn != originalOn { self.sendActions(for: .valueChanged) }
                
                self._tapStartingConditions = nil
            }
            
            break
        }
    }

    // handles button deep touch mode
    // TODO: animation/state interactions aren't really well-defined here... mostly relying on 't' to not depend on state
    // and for animations not to restart once deep touch begins... would be nice to have 'undefined' state, I guess
    @objc private func deepTouchEvents(recognizer: SimpleDeepTouchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            //print("deep touch recognition began")
            
            // AB: these recognizers are closer to "sensors" than true gestures, so they have to be directly cancelled
            // instead of setting up a gesture dependency graph; deep touch gesture replaces pan gesture when active
            self.regularTouchGestureRecognizer.cancel()
            
            // NOTE: the above calls the cancel action immediately, so cancellation animations will still be stopped
            self.animation = nil
            
            fallthrough
        case .changed:
            if self._deepTouchStartingConditions == nil {
                self._deepTouchStartingConditions = (position: recognizer.location(in: nil), time: CACurrentMediaTime(), value: self.isOn)
            }
                    
            if let startingConditions = self._deepTouchStartingConditions {
                //let p1 = recognizer.location(in: nil)
                //let localPoint = self.convert(p1, from: nil)
                
                let normalizedT = min(max((recognizer.t - recognizer.minimumForce) / (1 - recognizer.minimumForce), 0), 1)
                let tTail = log10(1 + normalizedT)*0.7
                
                if startingConditions.value {
                    if self.isOn {
                        self.lightHapticGenerator.prepare()
                        
                        if self.t >= self.snapOffT {
                            self.setOn(false, animated: false)
                            self.sendActions(for: .valueChanged)
                            
                            self.lightHapticGenerator.impactOccurred()
                        }
                        
                        self.t = self.snapOnT + tTail
                    }
                    else {
                        self.t = self.snapOnT + tTail
                    }
                }
                else {
                    if self.isOn {
                        // ignore -- incidentally, this also prevents interference with the animation
                    }
                    else {
                        self.hapticGenerator.prepare()
                        
                        self.t = normalizedT
                        
                        if self.t >= self.snapOnT {
                            self.isOn = true
                            self.sendActions(for: .valueChanged)
                            
                            self.hapticGenerator.impactOccurred()
                        }
                    }
                }
            }
        // NEXT: unravel this stuff
        case .ended:
            //print("deep touch gesture recognizer ended")
            
            if let startingConditions = self._deepTouchStartingConditions {
                
                // AB: force animation if we're on the wrong t, even if the state is correct; happens on 'off'
                // KLUDGE: we don't do this on 'on' b/c 'on' starts ignoring the gesture after triggering
//                if !self.isOn && self.t != t(forState: self.state) {
//                    let value: Bool = startingConditions.value
//                    let oldState: UIControlState = (value ? UIControlState.selected : UIControlState.normal)
//                    updateDisplayState(oldValue: oldState, newValue: self.state, oldT: self.t, animated: true, forced: true)
//                }
                
                // pressure gesture doesn't change 'on' state when ended, so we can't rely on implicit animations
                // KLUDGE: we don't do this on 'on' b/c we want the animation to keep playing
                if !self.isOn {
                    updateDisplayState(oldValue: self.state, newValue: self.state, oldT: self.t, animated: true, forced: true)
                }
                
                self._deepTouchStartingConditions = nil
            }
            
            break
        case .cancelled:
            //print("deep touch gesture recognizer cancelled")
            
            fallthrough
        default:
            if let startingConditions = self._deepTouchStartingConditions {
                if self.isOn != startingConditions.value {
                    self.isOn = startingConditions.value
                    self.sendActions(for: .valueChanged)
                }
                else {
                    // TODO: make sure this is actually correct -- fake state to ensure animation; prolly need something else,
                    // like animation for going from same state to same state
                    
                    var oldState: UIControlState = []
                    let oldT = self.t
                    
                    self.performAnimableChanges(animated: false) { _ in
                        self.isSelected = !startingConditions.value
                        oldState = self.state
                        self.isSelected = startingConditions.value
                        self.isDepressed = false
                    }
                    
                    updateDisplayState(oldValue: oldState, newValue: self.state, oldT: oldT, animated: true)
                }
                
                self._deepTouchStartingConditions = nil
            }
        }
    }
    
    // MARK: Rendering

    override open func draw(_ rect: CGRect) {
        if let block = renderBlock {
            block(self.t, self.snapOnT, rect, self.bounds, self.state, self.isOn)
        }
    }
    
    @objc private func animation(displayLink: CADisplayLink) {
        guard let animation = self.animation else {
            if let displayLink = self.animationDisplayLink {
                DebugCounter.counter.decrement(ForceButton.DebugDisplayLinksIdentifier)
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
                DebugCounter.counter.decrement(ForceButton.DebugDisplayLinksIdentifier)
                displayLink.invalidate()
                self.animationDisplayLink = nil
            }
        }
    }
    
    // MARK: Debugging
    
    private static var DebugDisplayLinksIdentifier: UInt = {
        let id: UInt = 100000 // TODO: find a way to avoid conflicts with outside users
        DebugCounter.counter.register(id: id, name: "FB Display Links")
        return id
    }()
    
    private static var DebugForceButtonsIdentifier: UInt = {
        let id: UInt = 100001
        DebugCounter.counter.register(id: id, name: "Force Buttons")
        return id
    }()
}

// MARK: - Helpers

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

// MARK: Extensions

// AB: not using .highlighted because highlights are automatic and we need manual control
extension UIControlState {
    //static let manualControl: UIControlState = {
    //    return UIControlState.customMask(n: 0)
    //}()
    public static let depressed: UIControlState = {
        return UIControlState.customMask(n: 1)
    }()
}

// MARK: Easing

fileprivate func dampenedSine(_ t: Double) -> Double {
    let initialAmplitude: Double = 0.5
    let decayConstant: Double = 4.5
    let numberOfBounces: Double = 2
    let angularFrequency: Double = 2 * Double.pi * numberOfBounces
    
    let returnT = initialAmplitude * pow(M_E, -decayConstant * t) * sin(angularFrequency * t)
    
    return returnT
}
