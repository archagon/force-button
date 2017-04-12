//
//  DemoCell.swift
//  ForceButton
//
//  Created by Alexei Baboulevitch on 2017-4-10.
//  Copyright © 2017 Alexei Baboulevitch. All rights reserved.
//

import UIKit
import ForceButtonFramework

// TODO: round sizes to nearest pixel
// TODO: cellShouldBeBroughtToFront only if allowed to open

protocol DemoCellDelegate: class {
    func cellDidSelectItem(cell: DemoPopupCell, item: Int)
    func cellShouldBeBroughtToFront(cell: DemoPopupCell)
    func cellVerticalPopupPosition(cell: DemoPopupCell, size: CGSize, anchorInsets: UIEdgeInsets) -> (rect: CGRect, edgeOverlap: UIEdgeInsets)
    func cellShouldBeginPopup(cell: DemoPopupCell) -> Bool
    func cellDidOpenPopup(cell: DemoPopupCell)
    func cellDidClosePopup(cell: DemoPopupCell)
}

// a collection view cell featuring a custom-drawn button and a 3d touch popup
class DemoPopupCell: UICollectionViewCell, UIGestureRecognizerDelegate {
    enum CellType {
        case popup
        case button
    }
    
    enum PopupState {
        case closed
        case pushing
        case opening
        case open
        case closing
    }
    
    weak var delegate: DemoCellDelegate?
    private var cellType: CellType
    
    // views
    private(set) var button: DemoButton
    private var popup: SelectionPopup?
    
    // gestures
    private var popupPressureGesture: SimpleDeepTouchGestureRecognizer
    private var popupSelectionGesture: SimpleMovementGestureRecognizer
    private var popupLongHoldGesture: UILongPressGestureRecognizer
    
    // popup state
    private var popupOpenAnimation: Animation?
    private var popupCloseAnimation: Animation?
    private var popupState: PopupState = .closed
    
    // hardware
    private var feedback: UIImpactFeedbackGenerator
    
    deinit {
        DebugCounter.counter.decrement(DemoPopupCell.DebugDemoCellsIdentifier, shouldLog: true)
    }
    
    override init(frame: CGRect) {
        DebugCounter.counter.increment(DemoPopupCell.DebugDemoCellsIdentifier, shouldLog: true)
        
        let rand = arc4random_uniform(2)
        self.cellType = (rand == 0 ? .popup : .button)
        
        let button = DemoButton()
        self.button = button
        self.popupPressureGesture = SimpleDeepTouchGestureRecognizer()
        self.popupSelectionGesture = SimpleMovementGestureRecognizer()
        self.popupLongHoldGesture = UILongPressGestureRecognizer()
        self.feedback = UIImpactFeedbackGenerator(style: .heavy)
        
        super.init(frame: frame)
        
        self.popupPressureGesture.addTarget(self, action: #selector(popupDeepTouch))
        self.popupSelectionGesture.addTarget(self, action: #selector(popupSelection))
        self.popupLongHoldGesture.addTarget(self, action: #selector(popupLongPress))
        self.popupPressureGesture.delegate = self
        self.popupSelectionGesture.delegate = self
        self.popupLongHoldGesture.delegate = self
        self.addGestureRecognizer(self.popupPressureGesture)
        self.addGestureRecognizer(self.popupSelectionGesture)
        self.addGestureRecognizer(self.popupLongHoldGesture)
        
        self.contentView.addSubview(button)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
        button.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        button.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        button.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
        
        buttonSetup: do {
            button.setColor((cellType == .popup ? UIColor.red : UIColor.green).lightenByAmount(0.5))
            button.addTarget(self, action: #selector(buttonOn), for: .valueChanged)
            button.supportsPressure = (cellType == .button)
            //button.showGradient = true
        }
        
        self.popupLongHoldGesture.isEnabled = (cellType == .popup)
        self.popupPressureGesture.isEnabled = (cellType == .popup)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // AB: allows popup selection outside cell bounds and closes popup when tapped outside
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        
        if view == nil {
            if let popup = self.popup {
                let popupPoint = self.convert(point, to: popup)
                let popupShape = popup.currentShape
                
                if popupShape.contains(popupPoint) {
                    return popup
                }
                else {
                    cancel()
                    return UIView() //KLUDGE: ensures that touches don't do anything
                }
            }
        }
        
        return view
    }
    
    override func prepareForReuse() {
        switchPopupState(.closed) //prevents animation
        cancel()
    }
    
    // MARK: Button Delegate
    
    func buttonOn(_ button: DemoButton) {
        closePopup()
    }
    
    // MARK: Gesture Actions
    
    func popupDeepTouch(gesture: SimpleDeepTouchGestureRecognizer) {
        // AB: gestures don't do anything when open(ing), but work at all other times
        if self.popupState == .open || self.popupState == .opening {
            return
        }
        
        let gestureOver = !(gesture.state == .began || gesture.state == .changed)
        
        if gestureOver  {
            closePopup()
        }
        else {
            openPopup(t: gesture.t)
        }
    }
    
    func popupLongPress(gesture: UILongPressGestureRecognizer) {
        // AB: gestures don't do anything when open(ing), but work at all other times
        if self.popupState == .open || self.popupState == .opening {
            return
        }
        
        let gestureRecognized = (gesture.state == .began || gesture.state == .recognized)
        
        if gestureRecognized {
            openPopup()
        }
    }
    
    func popupSelection(gesture: SimpleMovementGestureRecognizer) {
        if self.popupState != .open {
            return
        }
        
        let gestureOver = !(gesture.state == .began || gesture.state == .changed)
        
        if gestureOver {
            if let item = self.popup?.selectedItem {
                self.delegate?.cellDidSelectItem(cell: self, item: item)
                closePopup()
            }
        }
        else {
            self.popup?.changeSelection(gesture.location(in: nil))
        }
    }
    
    // MARK: Gesture Delegate
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if (gestureRecognizer == self.popupLongHoldGesture && otherGestureRecognizer == self.popupPressureGesture) ||
            (gestureRecognizer == self.popupPressureGesture && otherGestureRecognizer == self.popupLongHoldGesture)
        {
            // AB: this is more correct than calling cancel() whenever one or the other gesture is recognized,
            // but it's also more limiting... works for now, though, since pressure gesture has starting point
            return false
        }
        else {
            return true
        }
    }
    
    // MARK: Popup State Management
    
    func openPopup(t: Double? = nil) {
        if let t = t {
            let tStart: Double = 0.3
            let tEnd: Double = 0.75
            
            let scaledT: Double
            
            if t >= tEnd {
                scaledT = 0.5 + (t - tEnd) / (1 - tEnd) * 0.5
            }
            else if t >= tStart && t < tEnd {
                scaledT = ((t - tStart) / (tEnd - tStart)) * 0.5
            }
            else {
                scaledT = 0
            }
            
            if t >= tEnd {
                switchPopupState(.opening)
            }
            else {
                switchPopupState(.pushing)
            }
            
            if self.popupState == .pushing {
                self.popup?.t = scaledT
            }
        }
        else {
            switchPopupState(.opening)
        }
    }
    
    func closePopup() {
        switchPopupState(.closing)
    }
    
    // manages popup t state, animations, and also a few delegate calls; does not deal with gestures, hardware, etc.
    // NOTE: not all states can switch to all other states
    private func switchPopupState(_ state: PopupState) {
        // AB: these helper functions capture self, but do not escape the outer method, and thus there is no retain loop
        
        func addPopupIfNeeded() {
            if self.popup == nil {
                let popup = SelectionPopup(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
                
                for _ in 0..<(1 + arc4random_uniform(11)) {
                    //for _ in 0..<1 {
                    let view = UIView(frame: CGRect(x: 0,
                                                    y: 0,
                                                    width: CGFloat(100 + (Int(arc4random_uniform(50))-25)),
                                                    height: CGFloat(100 + (Int(arc4random_uniform(50))-25))))
                    view.backgroundColor = UIColor(hex: UInt(arc4random_uniform(0xffffff)))
                    popup.addSelectionView(view: view)
                }
                
                let superview = self.contentView
                superview.insertSubview(popup, at: 0)
                
                popup.sizeToFit()
                popup.layoutIfNeeded()
                
                guard let position = self.delegate?.cellVerticalPopupPosition(cell: self, size: popup.contentsFrame.size, anchorInsets: UIEdgeInsetsMake(popup.anchorExpandedInset.height, popup.anchorExpandedInset.width, popup.anchorExpandedInset.height, popup.anchorExpandedInset.width)) else {
                    // TODO: remove popup
                    assert(false)
                    return
                }
                
                // TODO: probably better to just compare blank frame to returned frame
                let baseAnchorFrame = CGRect(x: -popup.anchorExpandedInset.width, y: -popup.anchorExpandedInset.height, width: self.contentView.bounds.size.width + popup.anchorExpandedInset.width * 2, height: self.contentView.bounds.size.height + popup.anchorExpandedInset.height * 2)
                let anchorPosition = (baseAnchorFrame.midX - position.rect.origin.x)/position.rect.size.width
                let top = position.rect.maxY <= 0
                popup.anchorPosition = ((top ? 2 : 0), anchorPosition)
                
                popup.contentInset = position.edgeOverlap
                
                let anchorFrame = popup.anchorFrame
                let anchorCenter = CGPoint(x: anchorFrame.midX, y: anchorFrame.midY)
                let anchorCenterSuperview = popup.convert(anchorCenter, to: superview)
                let anchorTargetSuperview = self.convert(CGPoint(x: self.bounds.size.width * 0.5, y: self.bounds.size.height * 0.5), to: superview)
                let anchorDiff = CGPoint(x: anchorTargetSuperview.x - anchorCenterSuperview.x, y: anchorTargetSuperview.y - anchorCenterSuperview.y)
                
                popup.frame.origin = CGPoint(x: popup.frame.origin.x + anchorDiff.x,
                                             y: popup.frame.origin.y + anchorDiff.y)
                
                popup.color = button.darkColor.darkenByAmount(0.25)
                
                self.popup = popup
            }
        }
        
        func addPopupCloseAnimationIfNeeded() {
            guard let popup = self.popup else {
                return
            }
            
            if self.popupCloseAnimation == nil {
                self.popupCloseAnimation = Animation(duration: 0.1, delay: 0, start: CGFloat(popup.t), end: 0, block: {
                    [weak popup, weak self] (t: CGFloat, tScaled: CGFloat, val: CGFloat) in
                    
                    guard let popup = popup else {
                        return
                    }
                    guard let weakSelf = self else {
                        return
                    }
                    
                    popup.t = Double(val)
                    
                    if t >= 1 {
                        weakSelf.switchPopupState(.closed)
                    }
                    }, tFunc: { (t: Double)->Double in
                        // compensating for 0.5/0.5 split in popup parametric modes
                        let scaledT: Double
                        let divider: Double = 0.6
                        
                        if t <= divider {
                            scaledT = 0.5 * (t / divider)
                        }
                        else {
                            scaledT = 0.5 + 0.5 * ((t - divider) / (1 - divider))
                        }
                        
                        return linear(scaledT)
                })
                self.popupCloseAnimation?.start()
            }
        }
        
        func addPopupOpenAnimationIfNeeded() {
            guard let popup = self.popup else {
                return
            }
            
            if self.popupOpenAnimation == nil {
                self.popupOpenAnimation = Animation(duration: 0.25, delay: 0, start: 0.5, end: 1, block: {
                    [weak popup, weak self] (t: CGFloat, tScaled: CGFloat, val: CGFloat) in
                    
                    guard let popup = popup else {
                        return
                    }
                    guard let weakSelf = self else {
                        return
                    }
                    
                    popup.t = Double(val)
                    
                    if t >= 1 {
                        weakSelf.switchPopupState(.open)
                    }
                    }, tFunc: easeOutCubic)
                self.popupOpenAnimation?.start()
            }
        }
        
        let originalState = self.popupState
        var newState: PopupState = state
        
        // early return
        switch originalState {
        case .closed:
            switch newState {
            case .closed:
                fallthrough
            case .closing:
                return
            default:
                break
            }
        case .pushing:
            switch newState {
            case .pushing:
                return
            default:
                break
            }
        case .opening:
            switch newState {
            case .pushing:
                fallthrough
            case .opening:
                return
            default:
                break
            }
        case .open:
            switch newState {
            case .pushing:
                fallthrough
            case .opening:
                fallthrough
            case .open:
                return
            default:
                break
            }
        case .closing:
            switch newState {
            default:
                break
            }
        }
        
        // make sure popup is allowed to be opened
        if originalState == .closed {
            if !(self.delegate?.cellShouldBeginPopup(cell: self) ?? true) {
                return
            }
        }
        
        // adjust state
        switch newState {
        case .opening:
            if let popup = self.popup, popup.t == 1 {
                newState = .open
            }
        case .closing:
            if let popup = self.popup, popup.t == 0 {
                newState = .closed
            }
        default:
            break
        }
        
        //print("changing state from \(originalState) to \(newState)")
        
        switch newState {
        case .closed:
            self.popup?.removeFromSuperview()
            self.popup = nil
            self.popupOpenAnimation = nil
            self.popupCloseAnimation = nil
            self.delegate?.cellDidClosePopup(cell: self)
        case .pushing:
            addPopupIfNeeded()
            self.popup?.cancel()
            self.popupOpenAnimation = nil
            self.popupCloseAnimation = nil
        case .opening:
            addPopupIfNeeded()
            self.popup?.cancel()
            self.popupCloseAnimation = nil
            addPopupOpenAnimationIfNeeded()
        case .open:
            addPopupIfNeeded()
            self.popupOpenAnimation = nil
            self.popupCloseAnimation = nil
            self.popup?.t = 1
            self.delegate?.cellDidOpenPopup(cell: self)
        case .closing:
            addPopupIfNeeded()
            self.popup?.cancel()
            self.popupOpenAnimation = nil
            addPopupCloseAnimationIfNeeded()
        }
        
        self.popupState = newState
        
        makePopupStateConsistent(oldState: originalState, newState: newState)
    }
    
    // interface with non-popup stuff; ensures switchPopupState doesn't have to concern itself with things that call it,
    // e.g. gestures and their cancellation (even though it's called from switchPopupState, for convenience)
    func makePopupStateConsistent(oldState: PopupState, newState: PopupState) {
        do {
            self.delegate?.cellShouldBeBroughtToFront(cell: self)
            
            if oldState == .pushing && (newState == .open || newState == .opening) {
                self.feedback.impactOccurred()
            }
            
            if newState == .pushing {
                // usually happens when long hold is interrupted by pressure
                self.popupLongHoldGesture.cancel()
            }
            
            if newState == .opening {
                // neither opening gesture needs to persist after activation
                // BUGFIX: prevents long press from immediately reopening popup after selection
                self.popupPressureGesture.cancel()
                self.popupLongHoldGesture.cancel()
            }
            
            if newState == .opening || newState == .pushing {
                // TODO: should this also be called when .open or .closing?
                self.button.cancel()
            }
        }
        
        // asserts
        switch newState {
        case .closed:
            assert(self.popup == nil)
            assert(self.popupOpenAnimation == nil)
            assert(self.popupCloseAnimation == nil)
            break
        case .pushing:
            assert(self.popup != nil)
            assert(self.popupOpenAnimation == nil)
            assert(self.popupCloseAnimation == nil)
            break
        case .opening:
            assert(self.popup != nil)
            assert(self.popupOpenAnimation != nil)
            assert(self.popupCloseAnimation == nil)
            break
        case .open:
            assert(self.popup != nil)
            assert(self.popupOpenAnimation == nil)
            assert(self.popupCloseAnimation == nil)
            assert(self.popup!.t == 1)
            break
        case .closing:
            assert(self.popup != nil)
            assert(self.popupOpenAnimation == nil)
            assert(self.popupCloseAnimation != nil)
            break
        }
    }
    
    // MARK: Public Interface Methods
    
    func cancel() {
        // AB: these might be handled by makePopupStateConsistent, but better safe than sorry
        self.button.cancel()
        self.popupPressureGesture.cancel()
        self.popupLongHoldGesture.cancel()
        self.popupSelectionGesture.cancel()
        
        closePopup()
    }
    
    // hooks up to outside scroll view gestures to cancel whenever panning or zooming occurs
    // AB: can't use scroll view's 'touchesShouldCancel(in view:)' b/c apparently gestures are not cancelled by this
    func scrollViewCancellationHook(gesture: UIGestureRecognizer) {
        if gesture.state == .began {
            self.cancel()
        }
    }
    
    // MARK: Debugging
    
    private static var DebugDemoCellsIdentifier: UInt = {
        let id: UInt = 1
        DebugCounter.counter.register(id: id, name: "Demo Cells")
        return id
    }()
}
