//
//  Helpers.swift
//  ForceButton
//
//  Created by Alexei Baboulevitch on 2017-4-4.
//  Copyright © 2017 Alexei Baboulevitch. All rights reserved.
//

import Foundation
import UIKit

// a display link animation that automatically stops when the object is released (does not retain itself)
public class Animation {
    var linkHolder: LinkHolder?
    var generator: (()->((CADisplayLink)->()))
    
    public init(duration: TimeInterval, delay: TimeInterval, start: CGFloat, end: CGFloat, block: @escaping ((_ t: CGFloat, _ tScaled: CGFloat, _ val: CGFloat)->()), tFunc: ((Double)->(Double))?) {
        
        func generator() -> ((CADisplayLink)->()) {
            let originalTime = CACurrentMediaTime()
            let startTime = originalTime + delay
            
            func _block(link: CADisplayLink) {
                let time = link.timestamp - startTime
                
                if time < 0 {
                    return
                }
                
                let t = time / duration
                let tFunc = tFunc ?? linear
                let scaledT = CGFloat(tFunc(Double(t)))
                let val = start + scaledT * (end - start)
                
                block(CGFloat(t), CGFloat(scaledT), val)
            }
            
            return _block
        }
        
        self.generator = generator
    }
    
    public func start() {
        let linkHolder = LinkHolder(block: generator())
        self.linkHolder = linkHolder
    }
    
    class LinkHolder {
        deinit {
            self.link.invalidate()
        }
        
        class Target {
            var block: ((CADisplayLink)->())?
            
            @objc func callback(link: CADisplayLink) {
                if let block = block {
                    block(link)
                }
            }
        }
        
        var link: CADisplayLink
        var target: Target
        
        public init(block: @escaping ((CADisplayLink)->())) {
            let target = Target()
            target.block = block
            
            let link = CADisplayLink(target: target, selector: #selector(Target.callback(link:)))
            
            self.target = target
            self.link = link
            
            link.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
        }
    }
}
