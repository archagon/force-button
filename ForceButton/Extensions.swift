//
//  Extensions.swift
//  ForceButton
//
//  Created by Alexei Baboulevitch on 2017-4-5.
//  Copyright © 2017 Alexei Baboulevitch. All rights reserved.
//

import Foundation

extension UIControlState: Hashable {
    public var hashValue: Int {
        get {
            return self.rawValue.hashValue
        }
    }
}

extension UIColor {
    convenience public init(hex: UInt) {
        let b = ((hex >> 0) & 0xff)
        let g = ((hex >> 8) & 0xff)
        let r = ((hex >> 16) & 0xff)
        
        self.init(red: CGFloat(r)/CGFloat(0xff), green: CGFloat(g)/CGFloat(0xff), blue: CGFloat(b)/CGFloat(0xff), alpha: 1)
    }
    
    public var h: CGFloat {
        get {
            var h: CGFloat = 0
            self.getHue(&h, saturation: nil, brightness: nil, alpha: nil)
            return h
        }
    }
    public var s: CGFloat {
        get {
            var s: CGFloat = 0
            self.getHue(nil, saturation: &s, brightness: nil, alpha: nil)
            return s
        }
    }
    public var b: CGFloat {
        get {
            var b: CGFloat = 0
            self.getHue(nil, saturation: nil, brightness: &b, alpha: nil)
            return b
        }
    }
    
    public func mix(withColor mixColor: UIColor, byAmount amount: CGFloat) -> UIColor {
        var mixR: CGFloat = 0
        var mixG: CGFloat = 0
        var mixB: CGFloat = 0
        var mixA: CGFloat = 0
        mixColor.getRed(&mixR, green: &mixG, blue: &mixB, alpha: &mixA)
        
        let ratioB: CGFloat = amount
        let ratioA: CGFloat = 1 - amount
        
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        r = (ratioA * r + ratioB * mixR)
        g = (ratioA * g + ratioB * mixG)
        b = (ratioA * b + ratioB * mixB)
        a = (ratioA * a + ratioB * mixA)
        
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
    
    public func darkenByAmount(_ amount: CGFloat) -> UIColor {
        return self.mix(withColor: UIColor.black, byAmount: amount)
    }
    
    public func lightenByAmount(_ amount: CGFloat) -> UIColor {
        return self.mix(withColor: UIColor.white, byAmount: amount)
    }
}
