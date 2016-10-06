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
            
            button.addTarget(self, action: #selector(action(button:)), for: .valueChanged)
            
            button.renderBlock = { (t: Double, threshhold: Double, rect: CGRect, bounds: CGRect, state: ForceButton.State) in
                let offset: CGFloat = bounds.size.width * 0.2
                let actualOffset: CGFloat = offset - CGFloat(t) * (offset * 0.98)
                
                let s = (state.isOn ? 1 : CGFloat(min(0.25 + t / threshhold, 1)))
                let innerColor = UIColor(hue: 0.65, saturation: s, brightness: 1, alpha: 1)
                
                innerColor.setFill()
                let path = UIBezierPath(rect: CGRect(x: actualOffset, y: actualOffset, width: bounds.size.width - actualOffset * 2, height: bounds.size.height - actualOffset * 2))
                path.fill()
            }
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func action(button: ForceButton) {
            if button.on {
                self.perform(#selector(ding), with: nil, afterDelay: 0.05, inModes: [RunLoopMode.commonModes])
            }
        }
        func ding() {
            AudioServicesPlaySystemSound(0x450)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 60, height: 60)
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
