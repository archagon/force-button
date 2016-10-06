//
//  ViewController.swift
//  ForceButton
//
//  Created by Alexei Baboulevitch on 2016-10-5.
//  Copyright © 2016 Alexei Baboulevitch. All rights reserved.
//

import UIKit
import AudioToolbox

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let verticalStackView = UIStackView()
        verticalStackView.axis = .vertical
        verticalStackView.distribution = .fillEqually
        verticalStackView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(verticalStackView)
        verticalStackView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        verticalStackView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
        verticalStackView.widthAnchor.constraint(equalTo: verticalStackView.heightAnchor).isActive = true
        verticalStackView.heightAnchor.constraint(equalToConstant: 320).isActive = true
        
        for _ in 0..<5 {
            let horizontalStackView = UIStackView()
            horizontalStackView.axis = .horizontal
            horizontalStackView.distribution = .fillEqually
            horizontalStackView.translatesAutoresizingMaskIntoConstraints = false
            
            for _ in 0..<5 {
                let container = UIView()
                container.translatesAutoresizingMaskIntoConstraints = false
                
                let button = ForceButton(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
                button.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(button)
                button.widthAnchor.constraint(equalToConstant: 70).isActive = true
                button.heightAnchor.constraint(equalTo: button.widthAnchor).isActive = true
                button.centerXAnchor.constraint(equalTo: container.centerXAnchor).isActive = true
                button.centerYAnchor.constraint(equalTo: container.centerYAnchor).isActive = true
                
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
                
                horizontalStackView.addArrangedSubview(container)
            }
            
            verticalStackView.addArrangedSubview(horizontalStackView)
        }
    }
    
    func action(button: ForceButton) {
        if button.on {
            self.perform(#selector(ding), with: nil, afterDelay: 0.05)
        }
    }
    func ding() {
        AudioServicesPlaySystemSound(0x450)
    }
}
