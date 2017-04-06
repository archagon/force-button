//
//  ViewController.swift
//  ForceButton
//
//  Created by Alexei Baboulevitch on 2016-10-5.
//  Copyright © 2016 Alexei Baboulevitch. All rights reserved.
//

import UIKit
import AudioToolbox

// NEXT:
//  * fix force button
//  * long press
//  * re-enable scrolling

// NEXT:
//  * show under button & match color
//  * adjust curves

protocol CellDelegate: class {
    func cellShouldBeBroughtToFront(cell: DemoPopupCell)
    func cellVerticalPopupPosition(cell: DemoPopupCell, size: CGSize, anchorInsets: UIEdgeInsets) -> (rect: CGRect, edgeOverlap: UIEdgeInsets)
}

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, CellDelegate {

    class SlideyCollection : UICollectionView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
        
        override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
            super.init(frame: frame, collectionViewLayout: layout)
            
            self.delaysContentTouches = false
            self.canCancelContentTouches = true
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    class PoppyLayout: UICollectionViewFlowLayout {
        var lastItemPopped: IndexPath?
        
        func popItemAtIndexPath(indexPath: IndexPath) {
            var itemsToUpdate: [IndexPath] = []
            
            if let item = lastItemPopped {
                itemsToUpdate.append(item)
            }
            itemsToUpdate.append(indexPath)
            
            self.lastItemPopped = indexPath
            
            let invalidationContext = UICollectionViewFlowLayoutInvalidationContext()
            invalidationContext.invalidateItems(at: itemsToUpdate)
            self.invalidateLayout(with: invalidationContext)
        }
        
        override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
            let attributes = super.layoutAttributesForElements(in: rect)
            
            if let attributes = attributes {
                for attribute in attributes {
                    if let item = lastItemPopped, attribute.indexPath == item {
                        attribute.zIndex = 10
                    }
                    else {
                        attribute.zIndex = 0
                    }
                }
            }
            
            return attributes
        }
        
        override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            let attributes = super.layoutAttributesForItem(at: indexPath)
            
            if let item = lastItemPopped, indexPath == item {
                attributes?.zIndex = 10
            }
            else {
                attributes?.zIndex = 0
            }
            
            return attributes
        }
    }
    
    var collection: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let layout = PoppyLayout()
        let width = UIScreen.main.bounds.size.width / 6.0
        layout.itemSize = CGSize(width: width, height: width)
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        let collection = SlideyCollection(frame: CGRect(x: 0, y: 0, width: 100, height: 100), collectionViewLayout: layout)
        collection.dataSource = self
        collection.delegate = self
        collection.register(DemoPopupCell.self, forCellWithReuseIdentifier: "Cell")
        collection.contentInset = UIEdgeInsetsMake(20, 0, 0, 0)
        collection.backgroundColor = .clear
        collection.translatesAutoresizingMaskIntoConstraints = false
        
        self.collection = collection
        
        self.view.addSubview(collection)
        collection.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        collection.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        collection.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        collection.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        
        // QQQ:
        collection.isScrollEnabled = false
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1000
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let cell = cell as? DemoPopupCell {
            cell.delegate = self
            cell.button.on = false
        }
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
    
    func cellShouldBeBroughtToFront(cell: DemoPopupCell) {
        if let indexPath = self.collection.indexPath(for: cell) {
            (self.collection.collectionViewLayout as! PoppyLayout).popItemAtIndexPath(indexPath: indexPath)
        }
    }
    
    func cellVerticalPopupPosition(cell: DemoPopupCell, size: CGSize, anchorInsets: UIEdgeInsets) -> (rect: CGRect, edgeOverlap: UIEdgeInsets) {
        let edgeInset: CGFloat = 4
        
        if let _ = self.collection.indexPath(for: cell) {
            var workingRect = CGRect.zero
            workingRect.size = size
            
            let localAnchorRect = CGRect(x: -anchorInsets.left,
                                         y: -anchorInsets.top,
                                         width: cell.contentView.bounds.size.width + anchorInsets.left + anchorInsets.right,
                                         height: cell.contentView.bounds.size.height + anchorInsets.top + anchorInsets.bottom)
            let anchorRect = cell.convert(localAnchorRect, to: self.collection)
            
            vertical: do {
                let top = anchorRect.minY - edgeInset
                let bottom = -anchorRect.maxY + self.collection.bounds.size.height - edgeInset
                
                if size.height <= top {
                    workingRect.origin.y = localAnchorRect.minY - workingRect.size.height
                }
                else {
                    assert(size.height <= bottom, "popup could not fit vertically")
                    workingRect.origin.y = localAnchorRect.maxY
                }
            }
            
            horizontal: do {
                let left = anchorRect.midX - workingRect.size.width/2 - edgeInset
                let right = -(anchorRect.midX + workingRect.size.width/2) + self.collection.bounds.size.width - edgeInset
                
                let midX = (localAnchorRect.midX - workingRect.size.width/2)
                
                if left < 0 {
                    workingRect.origin.x = min(localAnchorRect.minX, midX - left)
                }
                else if right < 0 {
                    workingRect.origin.x = max(localAnchorRect.maxX - workingRect.size.width, midX + right)
                }
                else {
                    workingRect.origin.x = midX
                }
            }
            
            let collectionWorkingRect = cell.convert(workingRect, to: self.collection)
            let overlap = UIEdgeInsetsMake(max(0, 0 - collectionWorkingRect.minY),
                                           max(0, 0 - collectionWorkingRect.minX),
                                           max(0, collectionWorkingRect.maxY - self.collection.bounds.size.height),
                                           max(0, collectionWorkingRect.maxX - self.collection.bounds.size.width))
            
            
            return (workingRect, overlap)
        }
        
        return (CGRect.zero, UIEdgeInsets.zero)
    }
}

// a collection view cell featuring a custom-drawn button and a 3d touch popup
class DemoPopupCell: UICollectionViewCell, UIGestureRecognizerDelegate {
    enum PopupState {
        case closed
        case pushing
        case opening
        case open
        case closing
    }
    
    weak var delegate: CellDelegate?
    
    // views
    private(set) var button: DemoButton
    private var popup: SelectionPopup?
    
    // gestures
    private var popupGesture: SimpleDeepTouchGestureRecognizer
    private var popupSelectionGesture: SimpleMovementGestureRecognizer
    
    // popup state
    private var popupOpenAnimation: Animation?
    private var popupCloseAnimation: Animation?
    private var popupState: PopupState = .closed
    
    // hardware
    private var feedback: UIImpactFeedbackGenerator
    
    override init(frame: CGRect) {
        let button = DemoButton()
        self.button = button
        self.popupGesture = SimpleDeepTouchGestureRecognizer()
        self.popupSelectionGesture = SimpleMovementGestureRecognizer()
        self.feedback = UIImpactFeedbackGenerator(style: .heavy)
        
        super.init(frame: frame)
        
        self.popupGesture.addTarget(self, action: #selector(popupDeepTouch))
        self.popupSelectionGesture.addTarget(self, action: #selector(popupMovement))
        self.popupGesture.delegate = self
        self.popupSelectionGesture.delegate = self
        self.addGestureRecognizer(self.popupGesture)
        self.addGestureRecognizer(self.popupSelectionGesture)
        
        self.contentView.addSubview(button)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
        button.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        button.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        button.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
        
        buttonSetup: do {
            button.setColor(UIColor.blue.lightenByAmount(0.5))
            button.addTarget(self, action: #selector(buttonOn), for: .valueChanged)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        
        if view == nil {
            if let popup = self.popup {
                let popupPoint = self.convert(point, to: popup)
                let popupShape = popup.shape.shape
                
                if popupShape.contains(popupPoint) {
                    return popup
                }
                else {
                    closePopup()
                    return UIView() //KLUDGE: ensures that touches don't do anything
                }
            }
        }
        
        return view
    }
    
    func buttonOn(_ button: DemoButton) {
        closePopup()
    }
    
    func popupDeepTouch(gesture: SimpleDeepTouchGestureRecognizer) {
        self.delegate?.cellShouldBeBroughtToFront(cell: self)
        
        let gestureOver = !(gesture.state == .began || gesture.state == .changed)
        
        if self.popupState == .open || self.popupState == .opening {
            return
        }
        
        self.button.cancelTouches()
        
        if gestureOver  {
            closePopup()
        }
        else {
            openPopup(t: gesture.t)
        }
    }
    
    func popupMovement(gesture: SimpleMovementGestureRecognizer) {
        self.delegate?.cellShouldBeBroughtToFront(cell: self)
        
        let gestureOver = !(gesture.state == .began || gesture.state == .changed)
        
        if self.popupState != .open {
            return
        }
        
        if gestureOver {
            if self.popup?.selectedItem != nil {
                closePopup()
            }
        }
        else {
            self.popup?.changeSelection(gesture.location(in: nil))
        }
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func cancel() {
        // TODO: cancel gestures & button gestures
        self.button.cancelTouches()
        closePopup()
    }
    
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
        
            //TOOD: move
            if t >= tEnd {
                if self.popupState == .pushing {
                    self.feedback.impactOccurred()
                }
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
    
        validatePopupState()
    }
    
    func closePopup() {
        switchPopupState(.closing)
        validatePopupState()
    }
    
    // not all states can switch to all other states
    private func switchPopupState(_ state: PopupState) {
        // TODO: does non-weak self cause a retain loop?
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
                
                //weakButton.gesture.addTarget(popup, action: #selector(SelectionPopup.gestureRecognizerAction))
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
                        // compensating for 0.5/0.5 split
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
        case .closing:
            addPopupIfNeeded()
            self.popup?.cancel()
            self.popupOpenAnimation = nil
            addPopupCloseAnimationIfNeeded()
        }
        
        self.popupState = newState
    }
    
    func validatePopupState() {
        switch self.popupState {
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
}
