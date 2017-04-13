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

public class BezierBackgroundView: UIView {
    public var shape: UIBezierPath { didSet { shapeDidSet(oldValue) } }
    public var color: UIColor { didSet { colorDidSet(oldValue) } }
    
    func shapeDidSet(_ oldValue: UIBezierPath) {
        self.layerShape.path = self.shape.cgPath
    }
    func colorDidSet(_ oldValue: UIColor) {
        self.layerShape.fillColor = self.color.cgColor
    }
    
    override public class var layerClass: Swift.AnyClass {
        get {
            return CAShapeLayer.self
        }
    }
    
    public var layerShape: CAShapeLayer {
        get {
            return (self.layer as! CAShapeLayer)
        }
    }
    
    override public init(frame: CGRect) {
        self.shape = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height), cornerRadius: 0)
        self.color = UIColor.lightGray
        
        super.init(frame: frame)
        
        //self.backgroundColor = UIColor.lightGray
        
        defaults: do {
            // commit default values
            shapeDidSet(self.shape)
            colorDidSet(self.color)
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public class DebugCounter {
    public static let counter = DebugCounter()
    
    public var debugging: Bool = false
    
    public func register(id: UInt, name: String) {
        assert(identifiers[id] == nil, "\(name): already registered as \(getName(id))")
        identifiers[id] = name
    }
    
    public func increment(_ id: UInt, shouldLog: Bool = false) {
        counts[id] = (counts[id] ?? 0) + 1
        
        if shouldLog { log() }
    }
    
    public func decrement(_ id: UInt, shouldLog: Bool = false) {
        if let count = counts[id] {
            assert(count > 0, "\(getName(id)): trying to decrement zero count")
            counts[id] = max(count - 1, 0)
        }
        
        if shouldLog { log() }
    }
    
    public func log() {
        if !debugging {
            return
        }
        
        print("-------DEBUG-------")
        for count in counts {
            print("‣ \(getName(count.key)): \(count.value)")
        }
        print("--------END--------")
    }
    
    private func getName(_ id: UInt) -> String {
        return (identifiers[id] ?? id.description)
    }
    
    private var counts: [UInt:Int] = [:]
    private var identifiers: [UInt:String] = [:]
    
    private init() {}
}
