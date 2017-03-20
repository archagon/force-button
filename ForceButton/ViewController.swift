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
            
            buttonSetup: do {
                var showGradient = false
                var gradientHighlightAmount = 0
                
                button.tBlock = { [weak button] (t: Double, threshhold: Double, bounds: CGRect, state: UIControlState, value: Bool) in
                    guard let weakSelf = button else {
                        return
                    }
                    
                    if weakSelf.isEmphasized {
                        if weakSelf.isSelected {
                            gradientHighlightAmount = 0
                        }
                        else {
                            gradientHighlightAmount = 1
                        }
                    }
                    else {
                        gradientHighlightAmount = 0
                    }
                }
                
                // AB: on 'selected' state, we want the color to hold constant once we're past the selected threshhold
                var statePastThreshhold: (UIControlState, Bool)?
                button.renderBlock = { [weak button] (t: Double, threshhold: Double, rect: CGRect, bounds: CGRect, state: UIControlState, value: Bool) in
                    guard let weakSelf = button else {
                        return
                    }
                    
                    let button = weakSelf
                    
                    guard let _ = UIGraphicsGetCurrentContext() else {
                        return
                    }
                    
                    if statePastThreshhold == nil || statePastThreshhold?.0 != state {
                        statePastThreshhold = (state, false)
                    }
                    
                    // AB: design testing
                    //let ab = Int(Double(button.hash) / 100) % 8 == 0
                    let ab = false
                    let appearanceOptions: BubbleCellAppearanceAttribute = [ .cornerShadow, .darkerBottom ]
                    
                    //let cornerRadius = weakSelf.buttonVisualParameters().cornerRadius
                    
                    // color appearance constants
                    var shade: CGFloat = 0.25
                    
                    if ab && appearanceOptions.contains(.underlay) {
                        //gapSize = 3
                        //let bgColor = UIColor.black.withAlphaComponent(0.5)
                        //bgColor.setFill()
                        //UIBezierPath(roundedRect: bounds, cornerRadius: 5).fill()
                    }
                    
                    if ab && appearanceOptions.contains(.darkerBottom) {
                        shade = 0.3
                    }
                    
                    let downT = weakSelf.buttonTParameters(t: t, threshhold: threshhold).downT
                    //let upperInset = weakSelf.buttonTParameters(t: t, threshhold: threshhold).upperInset
                    let lowerPath = weakSelf.pathForButtonBottom(t: t, threshhold: threshhold)
                    let upperPath = weakSelf.pathForButtonTop(t: t, threshhold: threshhold)
                    
                    if t >= threshhold {
                        statePastThreshhold = (state, true)
                    }
                    
                    var hl: CGFloat = 0
                    var sl: CGFloat = 0
                    var bl: CGFloat = 0
                    var hd: CGFloat = 0
                    var sd: CGFloat = 0
                    var bd: CGFloat = 0
                    weakSelf.lightColor.getHue(&hl, saturation: &sl, brightness: &bl, alpha: nil)
                    weakSelf.darkColor.getHue(&hd, saturation: &sd, brightness: &bd, alpha: nil)
                    
                    //let s = (state.isOn ? 1 : CGFloat(0.3 + downT * 0.7))
                    let innerColor: UIColor
                    if button.isEmphasized && button.isSelected {
                        innerColor = UIColor.white
                    }
                    else {
                        let colorT = (state.contains(.selected) && (statePastThreshhold?.1 ?? false) ? 1 : downT)
                        innerColor = UIColor(
                            hue: hl + colorT * (hd - hl),
                            saturation: sl + colorT * (sd - sl),
                            brightness: bl + colorT * (bd - bl),
                            alpha: 1)
                    }
                    
                    let outsideDarkColor = innerColor.darkenByAmount(shade)

                    let clip = lowerPath
                    
                    // first clip: outer button
                    clip.addClip()
                    
                    outsideDarkColor.setFill()
                    lowerPath.fill()
                    
                    innerColor.setFill()
                    upperPath.fill()
                    
                    if showGradient {
                        upperPath.addClip()
                        
                        // AB: gradient is an image instead of an image view b/c image view clobbers performance on iPad --
                        // presumably due to constant re-layout on scroll
                        // KLUDGE: magic numbers
                        let gradientTween = CGFloat(gradientHighlightAmount)
                        weakSelf.gradient?.draw(in: bounds, blendMode: CGBlendMode.normal, alpha: (t < 0 ? 1+CGFloat(t)/0.07 : 1) * (1 - gradientTween))
                        if gradientTween > 0 {
                            weakSelf.gradientHighlight?.draw(in: bounds, blendMode: CGBlendMode.normal, alpha: (t < 0 ? 1+CGFloat(t)/0.07 : 1) * gradientTween)
                        }
                    }
                }
            }
            
//            button.renderBlock = { (_ t: Double, _ threshhold: Double, _ rect: CGRect, _ bounds: CGRect, _ state: UIControlState, _ value: Bool) in
//                // TODO: include in block
//                let tOffset = ForceButton.StandardTapForce
//                
//                let cornerRadius: CGFloat = 4
//                let upInset: CGFloat = 8
//                let downInset: CGFloat = 8
//                let widthCompression: CGFloat = 0.95
//                
//                let tScale = 1 - tOffset
//                let normalizedT = max((t - tOffset) / tScale, 0)
//                let normalizedThreshhold = max((threshhold - tOffset) / tScale, 0)
//                let adjustedT: CGFloat = CGFloat(normalizedT) / CGFloat(normalizedThreshhold)
//                
//                let totalInset = upInset + downInset
//                let lowerInset = max(8 - (adjustedT * totalInset), 0)
//                let upperInset = max(-8 + (adjustedT * totalInset), 0)
//                let adjustedWidth = widthCompression + (1 - min(max((upperInset/downInset), 0), 1)) * (1 - widthCompression)
//                
//                let downT = min(max(upperInset, 0)/downInset, 1)
//                let s = (state == UIControlState.depressed ? 1 : CGFloat(0.3 + downT * 0.7))
//                let innerColor = UIColor(hue: 0.65, saturation: s, brightness: 1, alpha: 1)
//                let outsideDarkColor = UIColor(hue: 0.65, saturation: 0.5, brightness: 0.7, alpha: 1)
//                let insideDarkColor = UIColor.black
//                
//                let clip = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius)
//                
//                let lowerPath = UIBezierPath(roundedRect: CGRect(x: 0, y: upInset, width: bounds.size.width, height: bounds.size.height - upInset), cornerRadius: cornerRadius)
//                let upperPath = UIBezierPath(roundedRect: CGRect(
//                    x: (bounds.size.width - (adjustedWidth * bounds.size.width)) / 2.0,
//                    y: upperInset + (upInset - lowerInset),
//                    width: adjustedWidth * bounds.size.width,
//                    height: bounds.size.height - upperInset - lowerInset), cornerRadius: cornerRadius)
//                
//                clip.addClip()
//                
//                if upperInset > 0 {
//                    insideDarkColor.setFill()
//                }
//                else {
//                    outsideDarkColor.setFill()
//                }
//                lowerPath.fill()
//                
//                innerColor.setFill()
//                upperPath.fill()
//            }
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let layout = UICollectionViewFlowLayout()
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
