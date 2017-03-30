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
        
        print("resetting simple pan")
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
        
        print("resetting simple press")
    }
}

extension UIGestureRecognizer {
    func cancel() {
        let wasEnabled = self.isEnabled
        self.isEnabled = false
        self.isEnabled = wasEnabled
    }
}
