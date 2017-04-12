//
//  ViewController.swift
//  ForceButton
//
//  Created by Alexei Baboulevitch on 2016-10-5.
//  Copyright © 2016 Alexei Baboulevitch. All rights reserved.
//

import UIKit
import AudioToolbox
import ForceButtonFramework

// NEXT:
//  * clean up force button w/gesture code
//      * force button should not be able to start during scrolling
//  * second touch next to held-open popup causes glitches
//  * only one popup open at a time
//  * wrong bounds for lower buttons
//  * can't select button while scrolling
//  * cleanup for non-force devices
//  * divide by zero -- open popup, then reload data
//  * check memory

/*
 
 This demo project has a whole bunch of features (semi-) working in concert:
 
   * 3 types of buttons: 3d touch enabled with no popups (red), regular with 3d touch popups (blue), and regular with long press popups (green).
   * Popups that are laid out and sized automatically based on their location on screen.
   * Popups that are always brought to the front when selected.
   * Popup items that you can select without releasing your finger after triggering the popup, like native 3d touch.
   * Popups that can be closed by tapping outside the popup.
   * Simultaneous scrolling, with button and popup gestures that are cancelled once scrolling starts.
   * When a popup is open and selecting stuff, scrolling is disabled and cannot cancel the popup.
   * Only a single popup can be open at once.
 
 The functionality to make all the above work is spread across several different files. Here are the important bits:
 
   * ViewController uses a custom subclass of UICollectionViewFlowLayout that allows index paths to be brought to the front.
   * DemoCell asks ViewController for popup layout information, requests popups to be brought to the front, and informs it of popups opening/closing.
   * DemoCell exposes a gesture action that ViewController binds to its pan and pinch gesture recognizers (cancellation).
   * DemoCell overrides hitTest for popup closing and to allow popup items to be selected outside the cell bounds.
   * SelectionPopup does not handle any of its own selection, and instead exposes a method that DemoCell calls through its pan gesture recognizer.
   * SelectionPopup does not handle any of its own peek/pop gestures, and instead exposes a 't' property. DemoCell controls it using several gestures.
 
 Kinda confusing, and a bit boilerplate-y, but hopefully all the components are sufficiently decoupled to prevent headaches.
 
 */

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, DemoCellDelegate {

    // AB: this used to be necessary, but not anymore now that everything's gesture based... need to revisit
    class SlideyCollection : UICollectionView {
//        override func touchesShouldCancel(in view: UIView) -> Bool {
//            return true
//        }
//        
//        override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
//            super.init(frame: frame, collectionViewLayout: layout)
//            
//            self.delaysContentTouches = false
//            self.canCancelContentTouches = true
//        }
//        
//        required init?(coder aDecoder: NSCoder) {
//            fatalError("init(coder:) has not been implemented")
//        }
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
    
    class ButtonHeader: UICollectionReusableView {
        var button: UIButton
        
        override init(frame: CGRect) {
            self.button = UIButton(type: .system)
            
            super.init(frame: frame)
            
            self.addSubview(button)
            
            button.translatesAutoresizingMaskIntoConstraints = false
            let hConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|-(h)-[button]-(h)-|", options: [], metrics: ["h":2], views: ["button":button])
            let vConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|-(v)-[button]-(v)-|", options: [], metrics: ["v":2], views: ["button":button])
            NSLayoutConstraint.activate(hConstraints + vConstraints)
            
            button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            button.layer.borderWidth = 1
            button.layer.cornerRadius = 8
            button.layer.borderColor = UIColor.blue.cgColor
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    var collection: UICollectionView!
    
    // MARK: View Controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let layout = PoppyLayout()
        let width = UIScreen.main.bounds.size.width / 6.0
        layout.itemSize = CGSize(width: width, height: width)
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.headerReferenceSize = CGSize(width: 200, height: 44)
        
        let collection = SlideyCollection(frame: CGRect(x: 0, y: 0, width: 100, height: 100), collectionViewLayout: layout)
        collection.dataSource = self
        collection.delegate = self
        collection.register(DemoPopupCell.self, forCellWithReuseIdentifier: "Cell")
        collection.register(ButtonHeader.self, forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: "Header")
        collection.contentInset = UIEdgeInsetsMake(20, 0, 0, 0)
        collection.backgroundColor = .clear
        collection.translatesAutoresizingMaskIntoConstraints = false
        
        self.collection = collection
        
        self.view.addSubview(collection)
        collection.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        collection.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        collection.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        collection.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        
        // DEBUG: for testing purposes
        //collection.isScrollEnabled = false
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
    
    // MARK: Collection Delegate
    
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
           
            // AB: cancels the cell popup & button gestures whenever anything interesting happens in the scroll view
            self.collection.panGestureRecognizer.addTarget(cell, action: #selector(DemoPopupCell.scrollViewCancellationHook))
            self.collection.pinchGestureRecognizer?.addTarget(cell, action: #selector(DemoPopupCell.scrollViewCancellationHook))
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let cell = cell as? DemoPopupCell {
            // TODO: not sure if this is necessary
            self.collection.panGestureRecognizer.removeTarget(cell, action: nil)
            self.collection.pinchGestureRecognizer?.removeTarget(cell, action: nil)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath)
        
        if let view = view as? ButtonHeader {
            view.button.setTitle("Reload Data", for: .normal)
            view.button.addTarget(self, action: #selector(reloadData), for: .touchUpInside)
        }

        return view
    }
    
    // MARK: Cell Delegate
    
    func cellDidSelectItem(cell: DemoPopupCell, item: Int) {
        print("cell selected item \(item)")
    }
    
    func cellShouldBeBroughtToFront(cell: DemoPopupCell) {
        if let indexPath = self.collection.indexPath(for: cell) {
            (self.collection.collectionViewLayout as? PoppyLayout)?.popItemAtIndexPath(indexPath: indexPath)
        }
    }
    
    func cellVerticalPopupPosition(cell: DemoPopupCell, size: CGSize, anchorInsets: UIEdgeInsets) -> (rect: CGRect, edgeOverlap: UIEdgeInsets) {
        let edgeInset: CGFloat = 4
        
        if let _ = self.collection.indexPath(for: cell) {
            // BUGFIX: self.collection would be more accurate, but doesn't work due to scroll view shenanigans
            guard let frameOfReference = self.view else {
                return (CGRect.zero, UIEdgeInsets.zero)
            }
            
            var workingRect = CGRect.zero
            workingRect.size = size
            
            let localAnchorRect = CGRect(x: -anchorInsets.left,
                                         y: -anchorInsets.top,
                                         width: cell.contentView.bounds.size.width + anchorInsets.left + anchorInsets.right,
                                         height: cell.contentView.bounds.size.height + anchorInsets.top + anchorInsets.bottom)
            let anchorRect = cell.contentView.convert(localAnchorRect, to: frameOfReference)
            
            vertical: do {
                let top = anchorRect.minY - edgeInset
                let bottom = -anchorRect.maxY + frameOfReference.bounds.size.height - edgeInset
                
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
                let right = -(anchorRect.midX + workingRect.size.width/2) + frameOfReference.bounds.size.width - edgeInset
                
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
            
            let collectionWorkingRect = cell.contentView.convert(workingRect, to: frameOfReference)
            
            let overlap = UIEdgeInsetsMake(max(0, 0 - collectionWorkingRect.minY),
                                           max(0, 0 - collectionWorkingRect.minX),
                                           max(0, collectionWorkingRect.maxY - frameOfReference.bounds.size.height),
                                           max(0, collectionWorkingRect.maxX - frameOfReference.bounds.size.width))
            
            
            return (workingRect, overlap)
        }
        
        return (CGRect.zero, UIEdgeInsets.zero)
    }
    
    // AB: all this stuff simulates exclusive touch, to prevent popups from opening over each other
    var popupHasBegun: Bool = false
    var popupIsOpen: Bool = false {
        didSet {
            // disable popup cancellation while a popup is open, so as to not interfere with selection
            self.collection.isScrollEnabled = !popupIsOpen
        }
    }
    
    func cellShouldBeginPopup(cell: DemoPopupCell) -> Bool {
        if popupHasBegun {
            return false
        }
        else {
            popupHasBegun = true
            return true
        }
    }
    
    func cellDidOpenPopup(cell: DemoPopupCell) {
        assert(popupHasBegun)
        popupIsOpen = true
    }
    
    func cellDidClosePopup(cell: DemoPopupCell) {
        popupIsOpen = false
        popupHasBegun = false
    }
    
    // MARK: Public Interface Methods
    
    func reloadData() {
        self.collection.reloadData()
    }
}
