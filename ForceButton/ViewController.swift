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
//  * bring to front
//  * selectable over cells
//  * only start after deep touch
//  * expand should animate (like button)
//  * show under button & match color
//  * hook up to gesture recognizers
//  * close popup if tapped outside
//  * show popup compensating for sides

protocol CellDelegate: class {
    func cellShouldBeBroughtToFront(cell: ViewController.Cell)
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
    
    class Cell: UICollectionViewCell, UIGestureRecognizerDelegate {
        weak var delegate: CellDelegate?
        
        private(set) var button: DemoButton
        private var popup: SelectionPopup?
        private var popupGesture: SimpleDeepTouchGestureRecognizer
        private var mirrorCell: UIView?
        
        override init(frame: CGRect) {
            let button = DemoButton()
            self.button = button
            self.popupGesture = SimpleDeepTouchGestureRecognizer()
            
            super.init(frame: frame)
            
            self.popupGesture.addTarget(self, action: #selector(popupDeepTouch))
            self.popupGesture.delegate = self
            self.addGestureRecognizer(self.popupGesture)
            
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
        
        func buttonOn(_ button: DemoButton) {
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let view = super.hitTest(point, with: event)
            
            if view == nil {
                if let popup = self.popup {
                    let popupPoint = self.convert(point, to: popup)
                    if popup.point(inside: popupPoint, with: event) {
                        return popup
                    }
                }
            }
            
            return view
        }
        
        func popupDeepTouch(gesture: SimpleDeepTouchGestureRecognizer) {
            self.delegate?.cellShouldBeBroughtToFront(cell: self)
            
            if !button.on && !(gesture.state == .began || gesture.state == .changed) {
                popup?.removeFromSuperview()
                popup = nil
                return
            }
            
            if popup == nil {
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
                
//                let mirror = self.snapshotView(afterScreenUpdates: true)
                
            }
            
            if button.on {
                popup?.alpha = 1
            }
            else {
                let scaledT = CGFloat(min((gesture.t - gesture.minimumForce) * 3, 1))
                //popup?.alpha = scaledT
                popup?.alpha = 1
                popup?.t = Double(scaledT)
            }
        }
        
        public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        func cancel() {
            // TODO: cancel gestures & button gestures
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
        collection.register(Cell.self, forCellWithReuseIdentifier: "Cell")
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
        if let cell = cell as? Cell {
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
    
    func cellShouldBeBroughtToFront(cell: ViewController.Cell) {
        if let indexPath = self.collection.indexPath(for: cell) {
            (self.collection.collectionViewLayout as! PoppyLayout).popItemAtIndexPath(indexPath: indexPath)
        }
    }
}

//TARGET_IPHONE_SIMULATOR
