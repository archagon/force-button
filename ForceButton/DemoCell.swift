//
//  DemoCell.swift
//  ForceButton
//
//  Created by Alexei Baboulevitch on 2017-4-10.
//  Copyright © 2017 Alexei Baboulevitch. All rights reserved.
//

import UIKit
import ForceButtonFramework

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
class DemoPopupCell: UICollectionViewCell, UIGestureRecognizerDelegate, SelectionPopupDelegate {
    enum CellType {
        case popup
        case button
    }
    
    weak var delegate: DemoCellDelegate?
    private var cellType: CellType
    
    // views
    private(set) var button: DemoButton
    private var popup: SelectionPopup?
    
    deinit {
        DebugCounter.counter.decrement(DemoPopupCell.DebugDemoCellsIdentifier, shouldLog: true)
    }
    
    override init(frame: CGRect) {
        DebugCounter.counter.increment(DemoPopupCell.DebugDemoCellsIdentifier, shouldLog: true)
        
        let rand = arc4random_uniform(5)
        self.cellType = (rand == 0 ? .popup : .button)
        
        let button = DemoButton()
        self.button = button
        
        super.init(frame: frame)
        
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
        
        if cellType == .popup {
            createPopup()
        }
        
        gestures: do {
            // allows gestures to still work even though the popup is under the button
            if let popup = self.popup {
                self.contentView.addGestureRecognizer(popup.popupLongHoldGesture)
                self.contentView.addGestureRecognizer(popup.popupPressureGesture)
                self.contentView.addGestureRecognizer(popup.popupSelectionGesture)
            }
            
            // not really necessary, but good for consistency
            self.contentView.addGestureRecognizer(self.button.regularTouchGestureRecognizer)
            self.contentView.addGestureRecognizer(self.button.deepTouchGestureRecognizer)
        }
    }
    
    func createPopup() {
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

            popup.color = button.darkColor.darkenByAmount(0.25)
            
            popup.delegate = self
            
            self.popup = popup
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // AB: allows popup selection outside cell bounds and closes popup when tapped outside
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)

        if view == nil {
            if let popup = popup, popup.isShowing {
                let popupPoint = self.convert(point, to: popup)
                let popupShape = popup.currentShape
                
                if popupShape.contains(popupPoint) {
                    return popup
                }
                else {
                    cancelAndClose()
                    return UIView() //KLUDGE: ensures that touches don't do anything
                }
            }
        }
        
        return view
    }
    
    override func prepareForReuse() {
        cancel()
        self.popup?.close(animated: false)
    }
    
    // MARK: Button Delegate
    
    func buttonOn(_ button: DemoButton) {
        self.popup?.cancel()
        self.popup?.close()
    }
    
    // MARK: Selection Popup Delegate
    
    func selectionPopupDidSelectItem(popup: SelectionPopup, item: Int) {
        self.delegate?.cellDidSelectItem(cell: self, item: item)
        popup.selectedItem = nil
    }
    
    func selectionPopupShouldBegin(popup: SelectionPopup) -> Bool {
        return (self.delegate?.cellShouldBeginPopup(cell: self) ?? false)
    }
    
    func selectionPopupShouldLayout(popup: SelectionPopup) {
        guard let position = self.delegate?.cellVerticalPopupPosition(cell: self, size: popup.contentsFrame.size, anchorInsets: UIEdgeInsetsMake(popup.anchorExpandedInset.height, popup.anchorExpandedInset.width, popup.anchorExpandedInset.height, popup.anchorExpandedInset.width)) else {
            // TODO: remove popup
            assert(false)
            return
        }
        
        let superview = self.contentView
        
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
    }
    
    func selectionPopupDidOpen(popup: SelectionPopup) {
        self.delegate?.cellDidOpenPopup(cell: self)
    }
    
    func selectionPopupDidClose(popup: SelectionPopup) {
        self.delegate?.cellDidClosePopup(cell: self)
    }
    
    func selectionPopupDidChangeState(popup: SelectionPopup, state: SelectionPopup.PopupState) {
        self.delegate?.cellShouldBeBroughtToFront(cell: self)
        
        if state == .opening || state == .pushing {
            // TODO: should this also be called when .open or .closing?
            self.button.cancel()
            self.button.isUserInteractionEnabled = false
        }
        else {
            self.button.isUserInteractionEnabled = true
        }
    }
    
    // MARK: Public Interface Methods
    
    func cancel() {
        self.button.cancel()
        self.popup?.cancel()
    }
    
    func cancelAndClose() {
        cancel()
        self.popup?.close()
    }
    
    // hooks up to outside scroll view gestures to cancel whenever panning or zooming occurs
    // AB: can't use scroll view's 'touchesShouldCancel(in view:)' b/c apparently gestures are not cancelled by this
    func scrollViewCancellationHook(gesture: UIPanGestureRecognizer) {
        // PERF: switching on .changed might make scrolling jittery b/c work done in 'cancel'
        if gesture.state == .began || gesture.state == .changed {
            // KLUDGE: when the user stops a moving scroll view, we want gestures to work; unfortunately,
            // this immediately sends a .began state, as opposed to triggering after moving a small distance when
            // scrolling from standstill, and one of the few ways to differentiate the two is to check the
            // gesture's translation (which will be zero when stopping a moving scroll view until the activation
            // radius is breached)
            let translation = gesture.translation(in: nil)

            if translation != CGPoint.zero {
                cancelAndClose()
            }
        }
    }
    
    // MARK: Debugging
    
    private static var DebugDemoCellsIdentifier: UInt = {
        let id: UInt = 1
        DebugCounter.counter.register(id: id, name: "Demo Cells")
        return id
    }()
}
