//
//  ViewController.swift
//  ForceButton
//
//  Created by Alexei Baboulevitch on 2016-10-5.
//  Copyright © 2016 Alexei Baboulevitch. All rights reserved.
//

import UIKit
import AudioToolbox

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

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
    
    class Cell: UICollectionViewCell {
        private(set) var button: ForceButton
        
        override init(frame: CGRect) {
            let button = ForceButton()
            self.button = button
            
            super.init(frame: frame)
            
            button.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview(button)
            button.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
            button.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
            button.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
            button.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
            
            button.renderBlock = { (t: Double, threshhold: Double, rect: CGRect, bounds: CGRect, state: ForceButton.State) in
                let tOffset = ForceButton.StandardTapForce
                
                let cornerRadius: CGFloat = 4
                let upInset: CGFloat = 8
                let downInset: CGFloat = 8
                let widthCompression: CGFloat = 0.95
                
                let tScale = 1 - tOffset
                let normalizedT = max((t - tOffset) / tScale, 0)
                let normalizedThreshhold = max((threshhold - tOffset) / tScale, 0)
                let adjustedT: CGFloat = CGFloat(normalizedT) / CGFloat(normalizedThreshhold)
                
                let totalInset = upInset + downInset
                let lowerInset = max(8 - (adjustedT * totalInset), 0)
                let upperInset = max(-8 + (adjustedT * totalInset), 0)
                let adjustedWidth = widthCompression + (1 - min(max((upperInset/downInset), 0), 1)) * (1 - widthCompression)
                
                let downT = min(max(upperInset, 0)/downInset, 1)
                let s = (state.isOn ? 1 : CGFloat(0.3 + downT * 0.7))
                let innerColor = UIColor(hue: 0.65, saturation: s, brightness: 1, alpha: 1)
                let outsideDarkColor = UIColor(hue: 0.65, saturation: 0.5, brightness: 0.7, alpha: 1)
                let insideDarkColor = UIColor.black
                
                let clip = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius)
                
                let lowerPath = UIBezierPath(roundedRect: CGRect(x: 0, y: upInset, width: bounds.size.width, height: bounds.size.height - upInset), cornerRadius: cornerRadius)
                let upperPath = UIBezierPath(roundedRect: CGRect(
                    x: (bounds.size.width - (adjustedWidth * bounds.size.width)) / 2.0,
                    y: upperInset + (upInset - lowerInset),
                    width: adjustedWidth * bounds.size.width,
                    height: bounds.size.height - upperInset - lowerInset), cornerRadius: cornerRadius)
                
                clip.addClip()
                
                if upperInset > 0 {
                    insideDarkColor.setFill()
                }
                else {
                    outsideDarkColor.setFill()
                }
                lowerPath.fill()
                
                innerColor.setFill()
                upperPath.fill()
            }
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 60, height: 60)
        layout.minimumLineSpacing = 4
        layout.minimumInteritemSpacing = 16
        
        let collection = SlideyCollection(frame: CGRect(x: 0, y: 0, width: 100, height: 100), collectionViewLayout: layout)
        collection.dataSource = self
        collection.delegate = self
        collection.register(Cell.self, forCellWithReuseIdentifier: "Cell")
        collection.contentInset = UIEdgeInsetsMake(20, 0, 0, 0)
        collection.backgroundColor = .clear
        collection.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(collection)
        collection.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        collection.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        collection.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        collection.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1000
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let cell = cell as? Cell {
            cell.button.on = false
        }
    }
}
