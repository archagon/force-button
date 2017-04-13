import UIKit
import UIKit.UIGestureRecognizerSubclass

// TODO: require exclusive touch type?
// TODO: multiple fingers

// Both of these gestures are a bit odd in that they're designed to be "sensors". In other words, they're
// continuous (not discrete) and shouldn't really be prevented by other gesture recognizers or prevent
// other gesture recognizers. Instead, they should be cancelled as appropriate.

// a single-touch recognizer that tracks all finger motion, just like a UIView
public class SimpleMovementGestureRecognizer: UIGestureRecognizer {
    private var firstTouch: UITouch?
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
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
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        if let touch = self.firstTouch, touches.contains(touch) {
            self.state = .changed
        }
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        if let touch = self.firstTouch, touches.contains(touch) {
            self.state = .ended
        }
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        if let touch = self.firstTouch, touches.contains(touch) {
            self.state = .cancelled
        }
    }
    
    override public func reset() {
        super.reset()
        
        self.firstTouch = nil
        
        //print("resetting simple pan")
    }
}

// TODO: one touch each

// a single-touch recognizer that tracks all finger pressure past a specified threshhold
public class SimpleDeepTouchGestureRecognizer: UIGestureRecognizer {
    public var minimumForce: Double = 0.18 //standard-ish tap
    public var nonForceDefaultValue: Double = 1 //returned on devices that don't support pressure
    public private(set) var t: Double = 0 //this is the pressure value
    
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
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        //print("touches began: \(touches.map { $0.hashValue }) (state \(self.state.rawValue))")
        
        super.touchesBegan(touches, with: event)
        
        if self.state == .possible, self.firstTouch == nil, let touch = touches.first {
            self.firstTouch = touch
            
            if force(touch) >= self.minimumForce {
                self.t = force(touch)
                
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
    
    // BUGFIX: fun fact -- if you don't change your state to .began or .changed, you won't get a touchesCancelled
    // call on gesture cancellation! this means we can't persist touches until we're past the threshhold (what is this???)
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        //print("touches moved: \(touches.map { $0.hashValue }) (state \(self.state.rawValue))")
        
        super.touchesMoved(touches, with: event)
        
        if let touch = self.firstTouch, touches.contains(touch) {
            if self.state == .possible {
                if force(touch) >= self.minimumForce {
                    self.t = force(touch)
                    
                    self.state = .began
                }
            }
            else {
                self.t = force(touch)
                
                self.state = .changed
            }
        }
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        //print("touches ended: \(touches.map { $0.hashValue }) (state \(self.state.rawValue))")
        
        super.touchesEnded(touches, with: event)
        
        if let touch = self.firstTouch, touches.contains(touch) {
            self.state = .ended
        }
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        //print("touches cancelled: \(touches.map { $0.hashValue }) (state \(self.state.rawValue))")
        
        super.touchesCancelled(touches, with: event)
        
        if let touch = self.firstTouch, touches.contains(touch) {
            self.state = .cancelled
        }
    }
    
    override public func reset() {
        super.reset()
        
        self.t = 0
        self.firstTouch = nil
        
        //print("resetting simple press")
    }
}

// like the above, but timer-based for use with the simulator
// TODO: TARGET_IPHONE_SIMULATOR
public class SimpleFakeDeepTouchGestureRecognizer: UIGestureRecognizer {
    public var minimumForce: Double = 0.18 //standard-ish tap
    public var nonForceDefaultValue: Double = 1 //doesn't actually don anything here
    public private(set) var t: Double = 0 //this is the pressure value
    
    private var firstTouch: UITouch?
    
    // fake touch stuff
    private var fakeForce: Double = 0 {
        didSet {
            if let touch = firstTouch {
                fakeTouchesMoved(touch)
            }
        }
    }
    private var fakeMaximumPossibleForce: Double = 1
    private var fakeForceTimer: (duration: TimeInterval, endValue: Double, easing: (Double)->Double)? {
        get {
            if let existingTimer = _fakeForceTimer {
                return (existingTimer.duration, existingTimer.endValue, existingTimer.easing)
            }
            else {
                return nil
            }
        }
        set {
            if let newTimer = newValue, let existingTimer = fakeForceTimer {
                if existingTimer.duration == newTimer.duration && existingTimer.endValue == newTimer.endValue {
                    return //do nothing, timer is the same
                }
            }
            
            if let existingTimer = _fakeForceTimer {
                existingTimer.link.invalidate()
            }
            _fakeForceTimer = nil
            
            if let newTimer = newValue {
                let link = CADisplayLink(target: self, selector: #selector(fakeForceTimerCallback(link:)))
                let startTime = CACurrentMediaTime()
                
                _fakeForceTimer = (link, startTime, self.fakeForce, newTimer.duration, newTimer.endValue, newTimer.easing)
                
                link.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
            }
        }
    }
    private var _fakeForceTimer: (link: CADisplayLink, startTime: TimeInterval, startValue: Double, duration: TimeInterval, endValue: Double, easing: (Double)->Double)?
    @objc private func fakeForceTimerCallback(link: CADisplayLink) {
        guard let existingTimer = _fakeForceTimer else {
            self.fakeForceTimer = nil
            return
        }
        
        let currentTime = CACurrentMediaTime()
        let linearT = (currentTime - existingTimer.startTime) / existingTimer.duration
        let t = min(max(existingTimer.easing(linearT), 0), 1)
        let force = existingTimer.startValue + t * (existingTimer.endValue - existingTimer.startValue)
        
        self.fakeForce = force
        
        if linearT >= 1 {
            self.fakeForceTimer = nil
            return
        }
    }
    
    private func force(_ touch: UITouch) -> Double {
        return Double(max(min(fakeForce / fakeMaximumPossibleForce, 1), 0))
    }
    
    private func startForce() {
        func easeOutCubic(_ t: Double) -> Double {
            return max(min(1 - pow(1 - t, 3), 1), 0)
        }
        
        self.fakeForceTimer = (3, 0.5, easeOutCubic)
    }
    
    private func endForce() {
        func easeOutCubic(_ t: Double) -> Double {
            return max(min(1 - pow(1 - t, 3), 1), 0)
        }
        
        self.fakeForceTimer = (1, 0, easeOutCubic)
    }
    
    private func cancelForce() {
        self.fakeForceTimer = nil
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if self.state == .possible, self.firstTouch == nil, let touch = touches.first {
            self.firstTouch = touch
            
            startForce()
            
            if force(touch) >= self.minimumForce {
                self.t = force(touch)
                
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
    
    func fakeTouchesMoved(_ newTouch: UITouch) {
        if let touch = self.firstTouch, touch == newTouch {
            if self.state == .possible {
                if force(touch) >= self.minimumForce {
                    self.t = force(touch)
                    
                    self.state = .began
                }
            }
            else {
                self.t = force(touch)
                
                self.state = .changed
            }
        }
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        endForce()
        
        if let touch = self.firstTouch, touches.contains(touch) {
            self.state = .ended
        }
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        cancelForce()
        
        if let touch = self.firstTouch, touches.contains(touch) {
            self.state = .cancelled
        }
    }
    
    override public func reset() {
        super.reset()
        
        self.t = 0
        self.firstTouch = nil
    }
}

extension UIGestureRecognizer {
    public func cancel() {
        let wasEnabled = self.isEnabled
        self.isEnabled = false
        self.isEnabled = wasEnabled
    }
}
