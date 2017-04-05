//
//  Easing.swift
//  ForceButton
//
//  Created by Alexei Baboulevitch on 2017-4-4.
//  Copyright © 2017 Alexei Baboulevitch. All rights reserved.
//

import Foundation

public func easeInCubic(_ t: Double) -> Double {
    return t * t * t
}

public func easeOutCubic(_ t: Double) -> Double {
    return max(min(1 - pow(1 - t, 3), 1), 0)
}

public func easeInQuart(_ t: Double) -> Double {
    return t * t * t * t
}

public func easeOutQuart(_ t: Double) -> Double {
    return max(min(1 - pow(1 - t, 4), 1), 0)
}

public func easeInExpo(_ t: Double) -> Double {
    return t == 0 ? 0 : pow(2, 10 * t - 10)
}

public func easeOutExpo(_ t: Double) -> Double {
    return t == 1 ? 1 : 1 - pow(2, -10 * t)
}

public func linear(_ t: Double) -> Double {
    return t
}
