import UIKit
import ForceButtonFramework

// AB: subclass abilities (isEmphasized, gradient) not really demonstrated in demo project — more for my own personal use
class DemoButton: ForceButton {
    // MARK: Constants and Stuff
    
    struct BubbleCellAppearanceAttribute: OptionSet {
        let rawValue: Int
        static let darkerBottom     = BubbleCellAppearanceAttribute(rawValue: 1 << 1)
        static let cornerShadow     = BubbleCellAppearanceAttribute(rawValue: 1 << 3)
    }
    
    // MARK: New States (Currently Unused in Demo)
    
    var isEmphasized: Bool = false {
        didSet {
            if oldValue != isEmphasized {
                updateDisplayState(settingSubState: .emphasized, toOn: isEmphasized)
            }
        }
    }
    func setIsEmphasized(_ val: Bool, animated: Bool=true) {
        let oldState = self.disableAutomaticAnimations
        self.disableAutomaticAnimations = !animated
        self.isEmphasized = val
        self.disableAutomaticAnimations = oldState
    }
    
    override var statesContributingToAppearance: [UIControlState:Selector] {
        get {
            var previous = super.statesContributingToAppearance
            
            previous[.emphasized] = #selector(getter:isEmphasized)
            
            return previous
        }
    }
    
    // easing function and duration will just be the defaults
    
    override func t(forState state: UIControlState) -> Double? {
        if state.contains(.emphasized) {
            return (self.isSelected ? -0.05 : 0)
        }
        else {
            return super.t(forState: state)
        }
    }
    
    override func duration(fromState: UIControlState, toState: UIControlState) -> TimeInterval {
        if fromState.contains(.emphasized) || toState.contains(.emphasized) {
            return 0.1
        }
        else {
            return super.duration(fromState: fromState, toState: toState)
        }
    }
    
    // MARK: Gradient (Currently Unused in Demo)
    
    var showGradient: Bool = false {
        didSet {
            if oldValue != showGradient {
                self.setNeedsDisplay()
            }
        }
    }
    
    // AB: not currently used
    var gradientHue: Double? {
        didSet {
            if gradientHue != oldValue {
                updateGradientColor()
            }
        }
    }
    
    private(set) var gradient: UIImage?
    private(set) var gradientHighlight: UIImage?
    
    private var gradientHighlightAmount: Double = 0 {
        didSet {
            if oldValue != gradientHighlightAmount {
                self.setNeedsDisplay()
            }
        }
    }
    
    // MARK: Colors
    
    private(set) var lightColor: UIColor = .white
    private(set) var darkColor: UIColor = .gray
    
    // MARK: Lifecycle
    
    deinit {
        DebugCounter.counter.decrement(DemoButton.DebugDemoButtonsIdentifier, shouldLog: true)
    }
    
    required init() {
        DebugCounter.counter.increment(DemoButton.DebugDemoButtonsIdentifier, shouldLog: true)
        
        super.init(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        self.tBlock = { [weak self] (t: Double, threshhold: Double, bounds: CGRect, state: UIControlState, value: Bool) in
            guard let weakSelf = self else {
                return
            }
            
            if weakSelf.isEmphasized {
                if weakSelf.isSelected {
                    weakSelf.gradientHighlightAmount = 0
                }
                else {
                    weakSelf.gradientHighlightAmount = 1
                }
            }
            else {
                weakSelf.gradientHighlightAmount = 0
            }
        }
        
        // AB: on 'selected' state, we want the color to hold constant once we're past the selected threshhold
        var statePastThreshhold: (UIControlState, Bool)?
        self.renderBlock = { [weak self] (t: Double, threshhold: Double, rect: CGRect, bounds: CGRect, state: UIControlState, value: Bool) in
            
            guard let weakSelf = self else {
                return
            }
            
            let button = weakSelf
            
            guard let _ = UIGraphicsGetCurrentContext() else {
                return
            }
            
            if statePastThreshhold == nil || statePastThreshhold?.0 != state {
                statePastThreshhold = (state, false)
            }
            
            // color appearance constants
            let shade: CGFloat = 0.25
            
            let downT = weakSelf.buttonTParameters(t: t, threshhold: threshhold).downT
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
            
            // first clip: outer button
            let clip = lowerPath
            clip.addClip()
            
            outsideDarkColor.setFill()
            lowerPath.fill()
            
            innerColor.setFill()
            upperPath.fill()
            
            if weakSelf.showGradient {
                upperPath.addClip()
                
                // AB: gradient is an image instead of an image view b/c image view clobbers performance on iPad --
                // presumably due to constant re-layout on scroll
                // KLUDGE: magic numbers
                let gradientTween = CGFloat(weakSelf.gradientHighlightAmount)
                weakSelf.gradient?.draw(in: bounds, blendMode: CGBlendMode.normal, alpha: (t < 0 ? 1+CGFloat(t)/0.07 : 1) * (1 - gradientTween))
                if gradientTween > 0 {
                    weakSelf.gradientHighlight?.draw(in: bounds, blendMode: CGBlendMode.normal, alpha: (t < 0 ? 1+CGFloat(t)/0.07 : 1) * gradientTween)
                }
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var previousSize: CGSize = CGSize.zero
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if self.bounds.size.equalTo(previousSize) {
            return
        }
        self.previousSize = self.bounds.size
        
        updateGradientColor()
        
        // updates mask, etc.
        let t = self.t
        self.t = t
    }
    
    // MARK: Updates
    
    func setColor(_ color: UIColor) {
        if !self.lightColor.isEqual(color) {
            self.setNeedsDisplay()
            
            let lightColor = color
            let darkColor = lightColor.darkenByAmount(0.4)
            
            self.lightColor = lightColor
            self.darkColor = darkColor
            
            updateGradientColor()
        }
    }
    
    func updateGradientColor() {
        // TODO: self.bounds b/c at this point gradient is not the correct size yet (?!)
        if !self.bounds.size.equalTo(CGSize.zero) {
            let gradientHue = self.gradientHue ?? Double(self.lightColor.h)
            let gradientColor = UIColor(hue: CGFloat(gradientHue), saturation: 1, brightness: self.lightColor.b - 0.15, alpha: 1)
            self.gradient = DemoButton.gradient(gradientColor, self.bounds.size)
            self.gradientHighlight = DemoButton.gradient(UIColor.white, self.bounds.size)
        }
    }
    
    // MARK: Appearance
    
    private func buttonVisualParameters() -> (scale: CGFloat, cornerRadius: CGFloat, upInset: CGFloat, downInset: CGFloat, widthCompression: CGFloat) {
        let noteSize: CGFloat = 40
        let gapSize: CGFloat = 3
        let cornerRadius: CGFloat = 8
        let upInset: CGFloat = 5
        let downInset: CGFloat = 3
        let widthCompression: CGFloat = 0.92
        
        let noteRatio = noteSize / (noteSize + gapSize)
        
        return (scale: noteRatio, cornerRadius: cornerRadius, upInset: upInset, downInset: downInset, widthCompression: widthCompression)
    }
    
    private func buttonTParameters(t: Double, threshhold: Double) -> (downT: CGFloat, adjustedWidth: CGFloat, lowerInset: CGFloat, upperInset: CGFloat) {
        let downInset = buttonVisualParameters().downInset
        let upInset = buttonVisualParameters().upInset
        let widthCompression = buttonVisualParameters().widthCompression
        
        let tOffset = 0.0
        
        let tScale = 1 - tOffset
        let normalizedT = t / tScale
        let normalizedThreshhold = threshhold / tScale
        let totalInset = upInset + downInset
        let adjustedT: CGFloat = CGFloat(normalizedT) / CGFloat(normalizedThreshhold)
        
        let lowerInset = max(upInset - (adjustedT * totalInset), 0)
        let upperInset = max(-upInset + (adjustedT * totalInset), 0)
        
        let adjustedWidth = widthCompression + (1 - min(max((upperInset/downInset), 0), 1)) * (1 - widthCompression)
        
        let downT = CGFloat(min(max(upperInset, 0)/downInset, 1))
        
        return (downT: downT, adjustedWidth: adjustedWidth, lowerInset: lowerInset, upperInset: upperInset)
    }
    
    private func pathForButtonTop(t: Double, threshhold: Double) -> UIBezierPath {
        let cornerRadius = buttonVisualParameters().cornerRadius
        let upInset = buttonVisualParameters().upInset
        let adjustedWidth = buttonTParameters(t: t, threshhold: threshhold).adjustedWidth
        let lowerInset = buttonTParameters(t: t, threshhold: threshhold).lowerInset
        let upperInset = buttonTParameters(t: t, threshhold: threshhold).upperInset
        
        let upperPathRect = CGRect(
            x: (bounds.size.width - (adjustedWidth * bounds.size.width)) / 2.0,
            y: upperInset + (upInset - lowerInset),
            width: adjustedWidth * bounds.size.width,
            height: bounds.size.height - upperInset - lowerInset)
        
        let upperPath = UIBezierPath(roundedRect: upperPathRect, cornerRadius: cornerRadius)
        
        let scale = buttonVisualParameters().scale
        let translation = self.bounds.size.width * (1 - scale) / 2.0
        upperPath.apply(CGAffineTransform(scaleX: scale, y: scale))
        upperPath.apply(CGAffineTransform(translationX: translation, y: translation))
        
        return upperPath
    }
    
    private func pathForButtonBottom(t: Double, threshhold: Double) -> UIBezierPath {
        let cornerRadius = buttonVisualParameters().cornerRadius
        
        let lowerPath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: bounds.size.width, height: bounds.size.height), cornerRadius: cornerRadius)
        
        let scale = buttonVisualParameters().scale
        let translation = self.bounds.size.width * (1 - scale) / 2.0
        lowerPath.apply(CGAffineTransform(scaleX: scale, y: scale))
        lowerPath.apply(CGAffineTransform(translationX: translation, y: translation))
        
        return lowerPath
    }
    
    // MARK: Debugging
    
    func debugStateBits(state: UIControlState) -> String {
        var string = ""
        
        if state.contains(.depressed) {
            string += "d"
        }
        if state.contains(.selected) {
            string += "s"
        }
        if state.contains(.emphasized) {
            string += "e"
        }
        
        return "["+string+"]"
    }
    
    // MARK: Gradient Cache
    
    // TODO: PERF: clear cache on change of conversation
    static var gradient: ((_ color: UIColor, _ size: CGSize)->UIImage) = {
        var gradientCache: [UInt64:UIImage] = [:]
        
        func _gradient(forColor color: UIColor, size: CGSize) -> UIImage {
            let colorHash: UInt64
            colorHash: do {
                var r: CGFloat = 0
                var g: CGFloat = 0
                var b: CGFloat = 0
                var a: CGFloat = 0
                
                color.getRed(&r, green: &g, blue: &b, alpha: &a)
                
                let max = CGFloat(UINT16_MAX)
                let rH = UInt64(r * max)
                let gH = UInt64(g * max)
                let bH = UInt64(b * max)
                let aH = UInt64(a * max)
                
                colorHash = (rH << (16*3)) | (gH << (16*2)) | (bH << (16*1)) | (aH << (16*0))
            }
            
            
            if let gradient = gradientCache[colorHash], gradient.size.equalTo(size) {
                return gradient
            }
            else {
                let appearanceOptions: BubbleCellAppearanceAttribute = [ .cornerShadow, .darkerBottom ]
                
                UIGraphicsBeginImageContextWithOptions(size, false, 0)
                
                guard let ctx = UIGraphicsGetCurrentContext() else {
                    assert(false, "could not get image context")
                    return UIImage()
                }
                
                func generateGradient(_ a: CGFloat, color: UIColor=UIColor.black, function: ((Double)->Double)?=nil, endT: CGFloat?=0.75) -> CGGradient? {
                    var gradientLocations: [CGFloat] = []
                    var gradientColors: [CGFloat] = []
                    
                    let steps: Int = 32
                    
                    let startT: CGFloat = 0
                    let endT: CGFloat = endT ?? 1
                    let startA: CGFloat = a
                    let endA: CGFloat = 0
                    
                    let tween: ((Double)->Double)
                    tween = function ?? { (t: Double)->Double in return t }
                    
                    var r: CGFloat = 0
                    var g: CGFloat = 0
                    var b: CGFloat = 0
                    var a: CGFloat = 0
                    color.getRed(&r, green: &g, blue: &b, alpha: &a)
                    
                    for s in 0..<steps {
                        let baseT = Double(s) / Double(steps - 1)
                        let tweenedT = tween(baseT)
                        
                        processValues: do {
                            let interpT = startT + CGFloat(baseT) * (endT - startT)
                            let interpA = startA + CGFloat(tweenedT) * (endA - startA)
                            
                            gradientLocations.append(interpT)
                            gradientColors += [ r, g, b, a * interpA ]
                        }
                    }
                    
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    
                    return CGGradient(colorSpace: colorSpace, colorComponents: &gradientColors, locations: &gradientLocations, count: gradientLocations.count)
                }
                
                do {
                    var gradLeftL = CGPoint(x: 0, y: size.height / 2)
                    var gradLeftR = CGPoint(x: size.width, y: size.height / 2)
                    var gradRightR = CGPoint(x: size.width, y: gradLeftL.y)
                    var gradRightL = CGPoint(x: size.width - size.width, y: gradLeftL.y)
                    
                    //top-bottom linear
                    var gradTop = CGPoint(x: size.width / 2, y: 0)
                    var gradBottom = CGPoint(x: size.width / 2, y: size.height)
                    
                    // bottom-top linear
                    let gradBTY = size.height - 3
                    var gradBTBottom = CGPoint(x: size.width / 2, y: gradBTY)
                    var gradBTTop = CGPoint(x: size.width / 2, y: gradBTY - size.height)
                    
                    // upper left corner linear
                    let gradCornerTop = CGPoint(x: 0, y: 0)
                    let gradCornerBottom = CGPoint(x: CGFloat(sqrt(pow(size.height, 2) / 2.0)),
                                                   y: CGFloat(sqrt(pow(size.height, 2) / 2.0)))
                    
                    ctx.setBlendMode(.normal)
                    
                    var r = size.width / 2.0
                    r *= 2
                    
                    let offset: CGFloat = 0
                    
                    gradTop.y -= offset
                    gradBottom.y -= offset
                    gradBTBottom.y += offset
                    gradBTTop.y += offset
                    
                    gradLeftL.x -= offset
                    gradLeftR.x -= offset
                    gradRightL.x += offset
                    gradRightR.x += offset
                    
                    if appearanceOptions.contains(.cornerShadow) {
                        if let gradient = generateGradient(1, color: color, function: nil) {
                            ctx.drawLinearGradient(gradient, start: gradCornerTop, end: gradCornerBottom, options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
                        }
                    }
                }
                
                let img = UIGraphicsGetImageFromCurrentImageContext()
                
                UIGraphicsEndImageContext()
                
                if let img = img {
                    gradientCache[colorHash] = img
                    
                    return img
                }
                else {
                    assert(false, "could not get image from current context")
                    return UIImage()
                }
            }
        }
        
        return _gradient
    }()
    
    // MARK: Debugging
    
    private static var DebugDemoButtonsIdentifier: UInt = {
        let id: UInt = 2
        DebugCounter.counter.register(id: id, name: "Demo Buttons")
        return id
    }()
}

// MARK: - Helpers -

// MARK: Extensions

extension UIControlState {
    static let emphasized: UIControlState = {
        return UIControlState.customMask(n: 2)
    }()
}
