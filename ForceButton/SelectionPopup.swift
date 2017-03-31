import UIKit
import UIKit.UIGestureRecognizerSubclass

fileprivate let UIArbitraryStartingFrame = CGRect(x: 0, y: 0, width: 100, height: 100)

// NEXT: one item popup
// NEXT: t slides box around
// NEXT: vertical
// NEXT: 2x horizontal

// NEXT: appearance when too thin
// NEXT: fix contents box connection
// NEXT: arbitrary position for stub
// NEXT: stub attachment point
// NEXT: show under button & match color
// NEXT: connnection different if close to side a la keyboard popups

protocol SelectionPopupDelegate {
}

// constants
extension SelectionPopup {
    // TODO: these should be instance variables
    static let stubCompactSize = CGSize(width: 62.5 - 3, height: 60)
    static let stubFullInsetSize = CGSize(width: 16, height: 16)
    static let stubFullSize =  CGSize(width: stubCompactSize.width + stubFullInsetSize.width * 2,
                                      height: stubCompactSize.height + stubFullInsetSize.height * 2)
    
    static let maximumSlopeAngle: CGFloat = 20
    static let maximumSlopeBezierRadius: CGFloat = 32
    static let minimumContentsMultiplierAlongStubAxis: CGFloat = 1.2 //QQQ: 1.2 produces incorrect newtonian result
}

class SelectionPopup: UIView, UIGestureRecognizerDelegate {
    // general properties
    public var arrowDirection: UIPopoverArrowDirection = .down {
        didSet { sizeToFit() }
    }
    public var selectedItem: Int? = nil {
        didSet {
            if selectedItem != oldValue {
                if selectedItem != nil {
                    self.selectionFeedback.selectionChanged()
                }
                
                for views in self.selectionViews {
                    views.selectionBox.backgroundColor = UIColor.clear
                }
            
                if let item = selectedItem, item < self.selectionViews.count {
                    let views = self.selectionViews[item]
                    views.selectionBox.backgroundColor = UIColor(hex: 0x007AFF)
                }
            }
        }
    }
    
    // appearance properties
    public var titleText: String {
        get {
            return self.title.text ?? ""
        }
        set {
            self.title.text = newValue
        }
    }
    public var titleFont: UIFont {
        get {
            return self.title.font
        }
        set {
            self.title.font = newValue
        }
    }
    public var titleColor: UIColor {
        get {
            return self.title.textColor
        }
        set {
            self.title.textColor = newValue
        }
    }
    public var color: UIColor {
        get {
            return self.shape.color
        }
        set {
            self.shape.color = newValue
        }
    }

    // layout properties
    public var itemHeight: CGFloat = 44 { //AB: assuming that width is reasonably close to height
        didSet { sizeToFit() }
    }
    public var itemSelectorMargin: CGFloat = 8 {
        didSet { sizeToFit() }
    }
    public var itemMargin: CGFloat = 4 {
        didSet { sizeToFit() }
    }
    public var maxItemsPerRow: Int = 4 {
        didSet { sizeToFit() }
    }
    
    // anchor properties
    public var anchorPosition: (side: Int, position: CGFloat) = (2, CGFloat(arc4random_uniform(1000))/CGFloat(999)) { //t,l,b,r -- +x,+y axis aligned (CG coords)
        didSet { sizeToFit() }
    }
    public var anchorFrame: CGRect {
        get {
            sizeToFit()
            let stubFrame = calculateStubFrame(boundingBox: self.bounds.size)
            return stubFrame
        }
    }
    
    // procedural properties
    public var t: Double = 0 {
        didSet {
            let stubFrame = calculateStubFrame(boundingBox: self.bounds.size)
            generateShape(stubFrame: stubFrame)
            
            self.gestureRecognizers!.first!.isEnabled = (t == 1)
            
            if self.contentsContainer.layer.mask == nil {
                let mask = CAShapeLayer()
                self.contentsContainer.layer.mask = mask
            }
            let mask = self.contentsContainer.layer.mask as! CAShapeLayer
            mask.frame = self.shape.bounds
            mask.path = self.shape.shape.cgPath
        }
    }
    
    // view properties
    var shape: BezierBackgroundView
    var contentsContainer: UIView
    var selectionViewContainer: UIView
    var title: UILabel
    var selectionViews: [(selectionBox: UIView, view: UIView)] = []
    
    // hardware stuff
    var selectionFeedback: UISelectionFeedbackGenerator
    
    override init(frame: CGRect) {
        self.previousSize = CGSize.zero
        
        let shape = BezierBackgroundView(frame: UIArbitraryStartingFrame)
        let contentsContainer = UIView(frame: UIArbitraryStartingFrame)
        let selectionViewContainer = UIView(frame: UIArbitraryStartingFrame)
        let title = UILabel()
        
        self.shape = shape
        self.contentsContainer = contentsContainer
        self.selectionViewContainer = selectionViewContainer
        self.title = title
        
        self.selectionFeedback = UISelectionFeedbackGenerator()
        
        super.init(frame: frame)
        
        self.backgroundColor = UIColor.yellow.withAlphaComponent(0.25)
        
        self.clipsToBounds = true
        
        viewLayoutSetup: do {
            self.addSubview(shape)
            self.addSubview(contentsContainer)
            contentsContainer.addSubview(selectionViewContainer)
            contentsContainer.addSubview(title)
        }
        
        viewAppearanceSetup: do {
            title.text = "Generic Popup"
            title.textColor = UIColor.white
            title.textAlignment = .center
        }
        
        let gesture = SimpleMovementGestureRecognizerTwo()
        gesture.addTarget(self, action: #selector(gestureRecognizerAction))
        gesture.delegate = self
        self.addGestureRecognizer(gesture)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Setup
    
    public func addSelectionView(view: UIView) {
        let selectionBox = UIButton(type: .custom)
        
        selectionViews.append((selectionBox, view))
        
        selectionBox.translatesAutoresizingMaskIntoConstraints = true
        selectionBox.layer.cornerRadius = 4
        selectionBox.backgroundColor = UIColor.clear
        selectionBox.tag = self.selectionViews.count - 1
        selectionBox.addTarget(self, action: #selector(tappedItem), for: .touchUpInside)
        selectionBox.isExclusiveTouch = true
        self.selectionViewContainer.addSubview(selectionBox)
        
        view.translatesAutoresizingMaskIntoConstraints = true
        view.isUserInteractionEnabled = false
        view.removeFromSuperview()
        self.selectionViewContainer.addSubview(view)
        
        sizeToFit()
    }
    
    public func gestureRecognizerAction(gestureRecognizer: UIGestureRecognizer) {
        // TODO: for now, finds matching item
        func findClosestItem(position: CGPoint) -> Int? {
            for (i, item) in self.selectionViews.enumerated() {
                let frame = item.selectionBox.convert(item.selectionBox.bounds, to: self)
                if frame.contains(position) {
                    return i
                }
            }
            
            return nil
        }
        
        let touch = gestureRecognizer.location(in: self)
        let item = findClosestItem(position: touch)
        
        self.selectionFeedback.prepare()
        self.selectedItem = item
        
        switch gestureRecognizer.state {
        case .began:
            print("began: \(item)")
        case .changed:
            print("changed: \(item)")
        case .ended:
            print("ended: \(item)")
        case .cancelled:
            print("cancelled: \(item)")
        default:
            break
        }
    }
    
    func tappedItem(button: UIButton) {
        self.selectedItem = button.tag
    }
    
    // MARK: Gestures
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    // MARK: Layout
    
    override func setNeedsLayout() {
        previousSize = nil
        
        super.setNeedsLayout()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if previousSize == nil || self.bounds.size != previousSize! {
            // KLUDGE:
            let selectionViewContainerTransform = self.selectionViewContainer.transform
            let titleTransform = self.title.transform
            self.selectionViewContainer.transform = CGAffineTransform.identity
            self.title.transform = CGAffineTransform.identity
            
            let layout = calculateFrames()
            let selectionLayout = calculateSelectionViewLayout()
            
            layoutSelectionViews: do {
                self.selectionViewContainer.frame.size = selectionLayout.boundingBox
                
                for (i, itemFrame) in selectionLayout.items.enumerated() {
                    let selectionBox = self.selectionViews[i].selectionBox
                    let view = self.selectionViews[i].view
                    
                    selectionBox.frame = itemFrame
                    view.frame = CGRect(x: itemFrame.origin.x + itemSelectorMargin,
                                        y: itemFrame.origin.y + itemSelectorMargin,
                                        width: itemFrame.size.width - itemSelectorMargin * 2,
                                        height: itemFrame.size.height - itemSelectorMargin * 2)
                }
            }
            
            layoutMainViews: do {
                self.title.frame = layout.title
                
                self.contentsContainer.frame = layout.contentsContainer
                
                self.selectionViewContainer.frame.origin = layout.selectionContainer.origin
                
                self.frame.size = layout.boundingBox
                
                self.shape.frame = self.bounds
            }
            
            // KLUDGE:
            self.selectionViewContainer.transform = selectionViewContainerTransform
            self.title.transform = titleTransform
            
            generateShape(stubFrame: layout.stub)
            
            previousSize = self.bounds.size
        }
    }
    var previousSize: CGSize?
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let layout = calculateFrames()
        
        return CGSize(width: layout.boundingBox.width, height: layout.boundingBox.height)
    }
    
    // MARK: Drawing
    
    func generateShape(stubFrame: CGRect) {
        enum Stage {
            case expand
            case bloom
        }
        
        func easeOutCubic(_ t: CGFloat) -> CGFloat {
            return max(min(1 - pow(1 - t, 3), 1), 0)
        }
        
        func circlePoint(c: CGPoint, r: CGFloat, a: CGFloat) -> CGPoint {
            return CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
        }
        
        func addCircle(_ shape: UIBezierPath, c: CGPoint, r: CGFloat) {
            shape.close()
            shape.move(to: CGPoint(x: c.x + r, y: c.x))
            shape.addArc(withCenter: c, radius: r, startAngle: 0, endAngle: CGFloat.pi, clockwise: true)
            shape.addArc(withCenter: c, radius: r, startAngle: CGFloat.pi, endAngle: 0, clockwise: true)
            shape.close()
        }
        
        // fixed top-level properties
        let stubExpandedInsetSize = SelectionPopup.stubFullInsetSize
        let contentsSize = self.contentsContainer.bounds.size
        
        // fixed t ranges
        let stubExpandTRange: ClosedRange<CGFloat> = CGFloat(0.0)...CGFloat(0.7)
        let stubRemoveTopCornersTRange: ClosedRange<CGFloat> = CGFloat(stubExpandTRange.upperBound)...CGFloat(stubExpandTRange.upperBound + 0.05)
        let stubSlopeTRange: ClosedRange<CGFloat> = CGFloat(stubRemoveTopCornersTRange.upperBound)...CGFloat(stubRemoveTopCornersTRange.upperBound + 0.15)
        let contentsExpandTRange: ClosedRange<CGFloat> = CGFloat(stubSlopeTRange.lowerBound)...CGFloat(stubSlopeTRange.upperBound)
        
        #if DEBUG
            for range in [stubExpandTRange, stubRemoveTopCornersTRange, stubSlopeTRange, contentsExpandTRange] {
                assert(range.lowerBound <= range.upperBound)
                assert(range.lowerBound >= 0)
                assert(range.upperBound <= 1)
            }
        #endif
        
        // fixed layout properties
        let stubStartCornerRadius: CGFloat = 4
        let stubEndCornerRadius: CGFloat = 12
        let contentsCornerRadius: CGFloat = 16
        let minStubSlopeClampedT: CGFloat = 0.5 //the slope angle and bezier can be clamped if too close to contents side
        
        // calculated t
        var stubExpandedT = min(max((CGFloat(self.t) - stubExpandTRange.lowerBound) / (stubExpandTRange.upperBound - stubExpandTRange.lowerBound), 0), 1)
        stubExpandedT = easeOutCubic(stubExpandedT)
        let stubRemoveTopCornersT = min(max((CGFloat(self.t) - stubRemoveTopCornersTRange.lowerBound) / (stubRemoveTopCornersTRange.upperBound - stubRemoveTopCornersTRange.lowerBound), 0), 1)
        let stubSlopeT = min(max((CGFloat(self.t) - stubSlopeTRange.lowerBound) / (stubSlopeTRange.upperBound - stubSlopeTRange.lowerBound), 0), 1)
        let contentsExpandT = min(max((CGFloat(self.t) - contentsExpandTRange.lowerBound) / (contentsExpandTRange.upperBound - contentsExpandTRange.lowerBound), 0), 1)
        
        // animation stage
        let stage = (stubSlopeT > 0 ? Stage.bloom : Stage.expand)
        
        // stub frame
        let stubTInverseInset = CGSize(width: stubExpandedInsetSize.width * (1 - stubExpandedT),
                                       height: stubExpandedInsetSize.height * (1 - stubExpandedT))
        let stubTFrame = CGRect(x: stubFrame.origin.x + stubTInverseInset.width,
                                y: stubFrame.origin.y + stubTInverseInset.width,
                                width: stubFrame.width - stubTInverseInset.width * 2,
                                height: stubFrame.height - stubTInverseInset.height * 2)
        
        // stub interpolated properties
        let stubTLowerCornerRadius = stubStartCornerRadius + (stubEndCornerRadius - stubStartCornerRadius) * stubExpandedT //lower corner
        let stubTUpperCornerRadius = stubTLowerCornerRadius + stubRemoveTopCornersT * (0 - stubTLowerCornerRadius) //upper corner in first animation stage
        let stubTLowerCornerCircleL = CGPoint(x: stubTFrame.minX + stubTLowerCornerRadius, y: stubTFrame.maxY - stubTLowerCornerRadius)
        let stubTLowerCornerCircleR = CGPoint(x: stubTFrame.maxX - stubTLowerCornerRadius, y: stubTFrame.maxY - stubTLowerCornerRadius)
        
        // slope derived properties (general)
        var slopeLCannotCurve: Bool = false
        var slopeRCannotCurve: Bool = false
        
        // slope derived properties (dual use)
        var slopeLStart: CGPoint //connection to lower circle
        var slopeRStart: CGPoint //connection to lower circle
        var slopeLEnd: CGPoint //connection to bezier if curving, or to contents corner if not
        var slopeREnd: CGPoint //connection to bezier if curving, or to contents corner if not
        var slopeAngleL: CGFloat = 0
        var slopeAngleR: CGFloat = 0
        
        // slope derived properties (far enough from the sides to curve)
        let slopeLStartCurveStart: CGPoint
        let slopeLStartCurveEnd: CGPoint
        let slopeRStartCurveStart: CGPoint
        let slopeRStartCurveEnd: CGPoint
        
        slopeMath: do {
            let slopeLFarthestPossibleT: CGFloat
            let slopeRFarthestPossibleT: CGFloat
            
            calculateMaxSlopeExtent: do {
                let stubEndFrame = stubFrame
                
                distanceApproximation: do {
                    let slopeLFarthestPossibleXPointWithoutBezier = min(contentsCornerRadius, stubFrame.minX)
                    let slopeRFarthestPossibleXPointWithoutBezier = max(contentsSize.width - contentsCornerRadius, stubFrame.maxX)
                    let baseBezierRadius = SelectionPopup.maximumSlopeBezierRadius
                    let baseAngle = SelectionPopup.maximumSlopeAngle * ((2 * CGFloat.pi) / 360.0)
                    let maxXDistanceR = slopeRFarthestPossibleXPointWithoutBezier - stubEndFrame.maxX
                    let maxXDistanceL = -slopeLFarthestPossibleXPointWithoutBezier + stubEndFrame.minX
                    let height = stubEndFrame.height
                    let aL = maxXDistanceL/height
                    let aR = maxXDistanceR/height
                    let b = baseBezierRadius/(baseAngle*height)
                    
                    let ffx = { (a: CGFloat, b: CGFloat)->((CGFloat)->CGFloat) in
                        return { (angle: CGFloat) -> CGFloat in
                            return a - b * angle - tan(angle)
                        }
                    }
                    let ffdx = { (a: CGFloat, b: CGFloat)->((CGFloat)->CGFloat) in
                        return { (angle: CGFloat) -> CGFloat in
                            return -b - pow(1 / cos(angle), 2)
                        }
                    }
                    let cleanup = { (angle: CGFloat) -> CGFloat in
                        return fmodpos(a: angle, b: CGFloat.pi/2)
                    }
                    
                    let angleLU = newton(function: ffx(aL, b), derivative: ffdx(aL, b), transform: cleanup, x0: CGFloat.pi/4)
                    let angleRU = newton(function: ffx(aR, b), derivative: ffdx(aR, b), transform: cleanup, x0: CGFloat.pi/4)
                    guard let angleL = angleLU else { assert(false); return; }
                    guard let angleR = angleRU else { assert(false); return; }
                    
                    slopeLFarthestPossibleT = angleL/baseAngle
                    slopeRFarthestPossibleT = angleR/baseAngle
                }
            }
            
            slopeLCannotCurve = slopeLFarthestPossibleT < minStubSlopeClampedT
            slopeRCannotCurve = slopeRFarthestPossibleT < minStubSlopeClampedT
            let slopeLT = (slopeLCannotCurve ? 0 : stubSlopeT * min(max(slopeLFarthestPossibleT, 0), 1))
            let slopeRT = (slopeRCannotCurve ? 0 : stubSlopeT * min(max(slopeRFarthestPossibleT, 0), 1))
            
            slopeAngleL = slopeLT * (SelectionPopup.maximumSlopeAngle * ((2 * CGFloat.pi) / 360.0))
            slopeAngleR = slopeRT * (SelectionPopup.maximumSlopeAngle * ((2 * CGFloat.pi) / 360.0))
            let stubTSlopeContentsBezierRadiusL = SelectionPopup.maximumSlopeBezierRadius * slopeLT
            let stubTSlopeContentsBezierRadiusR = SelectionPopup.maximumSlopeBezierRadius * slopeRT
            
            // stub corner/slope key properties
            // no need to add pi/2 b/c measured from right, not from top
            // end = connection to lower circle, start = connection to contents box
            slopeLEnd = circlePoint(c: stubTLowerCornerCircleL, r: stubTLowerCornerRadius, a: -slopeAngleL + CGFloat.pi)
            slopeREnd = circlePoint(c: stubTLowerCornerCircleR, r: stubTLowerCornerRadius, a: slopeAngleR)
            let slopeLHeight = slopeLEnd.y - stubTFrame.minY
            let slopeRHeight = slopeREnd.y - stubTFrame.minY
            let slopeLWidth = slopeLHeight * tan(slopeAngleL)
            let slopeRWidth = slopeRHeight * tan(slopeAngleR)
            slopeLStart = CGPoint(x: slopeLEnd.x - slopeLWidth, y: slopeLEnd.y - slopeLHeight)
            slopeRStart = CGPoint(x: slopeREnd.x + slopeRWidth, y: slopeREnd.y - slopeRHeight)
            
            // stub corner/slope vector math
            let slopeLVector = CGPoint(x: slopeLStart.x - slopeLEnd.x, y: slopeLStart.y - slopeLEnd.y)
            let slopeRVector = CGPoint(x: slopeRStart.x - slopeREnd.x, y: slopeRStart.y - slopeREnd.y)
            let slopeLength = sqrt(pow(slopeRVector.x, 2) + pow(slopeRVector.y, 2))
            let slopeLVectorNorm = CGPoint(x: slopeLVector.x / slopeLength, y: slopeLVector.y / slopeLength)
            let slopeRVectorNorm = CGPoint(x: slopeRVector.x / slopeLength, y: slopeRVector.y / slopeLength)
            let slopeLVectorUpperRadius = CGPoint(x: slopeLVectorNorm.x * stubTSlopeContentsBezierRadiusL,
                                                  y: slopeLVectorNorm.y * stubTSlopeContentsBezierRadiusL)
            let slopeRVectorUpperRadius = CGPoint(x: slopeRVectorNorm.x * stubTSlopeContentsBezierRadiusR,
                                                  y: slopeRVectorNorm.y * stubTSlopeContentsBezierRadiusR)
            
            // QQQ: not the best way to do this
            if slopeLCannotCurve {
                slopeLStartCurveStart = CGPoint(x: stubFrame.minX, y: stubFrame.minY)
                slopeLStartCurveEnd = slopeLStartCurveStart
            }
            else {
                slopeLStartCurveStart = CGPoint(x: slopeLStart.x - stubTSlopeContentsBezierRadiusL, y: slopeLStart.y)
                slopeLStartCurveEnd = CGPoint(x: slopeLEnd.x + slopeLVector.x - slopeLVectorUpperRadius.x,
                                              y: slopeLEnd.y + slopeLVector.y - slopeLVectorUpperRadius.y)
                
            }
            
            if slopeRCannotCurve {
                slopeRStartCurveStart = CGPoint(x: stubFrame.maxX, y: stubFrame.minY)
                slopeRStartCurveEnd = slopeRStartCurveStart
            }
            else {
                slopeRStartCurveStart = CGPoint(x: slopeRStart.x + stubTSlopeContentsBezierRadiusR, y: slopeRStart.y)
                slopeRStartCurveEnd = CGPoint(x: slopeREnd.x + slopeRVector.x - slopeRVectorUpperRadius.x,
                                              y: slopeREnd.y + slopeRVector.y - slopeRVectorUpperRadius.y)
            }
        }
    
        // contents frame
        let contentsLeftDistance = stubTFrame.minX
        let contentsRightDistance = contentsSize.width - stubTFrame.maxX
        let contentsVerticalDistance = contentsSize.height
        let contentsTIdealXL = stubTFrame.minX - contentsLeftDistance * contentsExpandT
        let contentsTIdealXR = stubTFrame.maxX + contentsRightDistance * contentsExpandT
        let contentsTXL = min(slopeLStartCurveStart.x, contentsTIdealXL)
        let contentsTXR = max(slopeRStartCurveStart.x, contentsTIdealXR)
        let contentsTHeight = contentsVerticalDistance * contentsExpandT
        let contentsTFrame = CGRect(x: contentsTXL,
                                    y: stubTFrame.minY - contentsTHeight,
                                    width: contentsTXR - contentsTXL,
                                    height: contentsTHeight)
        
        // contents corners
        let contentsTStubStartOverhang = slopeLStartCurveStart.x - contentsTFrame.minX
        let contentsTStubEndOverhang = -slopeRStartCurveStart.x + contentsTFrame.maxX
        let contentsTMaxCornerRadius = min(contentsTFrame.size.height/2, contentsCornerRadius)
        let contentsTStubStartCornerRadius = min(contentsTMaxCornerRadius, contentsTStubStartOverhang)
        let contentsTStubEndCornerRadius = min(contentsTMaxCornerRadius, contentsTStubEndOverhang)
        let contentsEndCornerL = CGPoint(x: contentsTFrame.minX + contentsTStubStartCornerRadius,
                                         y: contentsTFrame.maxY - contentsTStubStartCornerRadius)
        let contentsEndCornerR = CGPoint(x: contentsTFrame.maxX - contentsTStubEndCornerRadius,
                                         y: contentsTFrame.maxY - contentsTStubEndCornerRadius)
        
        print("corner 1: \(contentsEndCornerL), 2: \(contentsEndCornerR), \(slopeLStartCurveStart), \(slopeRStartCurveStart)")
        
        var tempOverflowAngleL: CGFloat = 0
        var tempOverflowAngleR: CGFloat = 0
        
        cornerConnectionApproximation: do {
            // flip for UR diagonal
            let contentsEndCornerL = CGPoint(x: 2 * stubTLowerCornerCircleL.x - contentsTFrame.minX - contentsTStubStartCornerRadius,
                                             y: contentsTFrame.maxY - contentsTStubStartCornerRadius)
            
            let contentsCornerRadiusL = contentsTStubStartCornerRadius
            let contentsCornerRadiusR = contentsTStubEndCornerRadius
            let stubCornerRadius = stubTLowerCornerRadius
            
            let ffx = { (bottomCorner: CGPoint, topCorner: CGPoint, bottomCornerRadius: CGFloat, topCornerRadius: CGFloat)->((CGFloat)->CGFloat) in
                return { (angle: CGFloat) -> CGFloat in
                    let a = (-topCornerRadius * cos(angle))
                    let b = (bottomCorner.x + bottomCornerRadius * cos(angle) - (topCorner.x + topCornerRadius * cos(angle)))
                    let c = (-topCornerRadius * sin(angle))
                    let d = (bottomCorner.y + bottomCornerRadius * sin(angle) - (topCorner.y + topCornerRadius * sin(angle)))
                    
                    return a * b + c * d
                }
            }
            let ffdx = { (bottomCorner: CGPoint, topCorner: CGPoint, bottomCornerRadius: CGFloat, topCornerRadius: CGFloat)->((CGFloat)->CGFloat) in
                return { (angle: CGFloat) -> CGFloat in
                    return topCornerRadius * ((bottomCorner.x - topCorner.x) * sin(angle) + (topCorner.y - bottomCorner.y) * cos(angle))
                }
            }
            let cleanup = { (angle: CGFloat) -> CGFloat in
                return fmodpos(a: angle, b: CGFloat.pi * 2)
            }
            
            //NEXT: reflect along axis
            //NEXT: shortcut for r == 0
            
            let lAngleU = newton(function: ffx(stubTLowerCornerCircleL, contentsEndCornerL, stubCornerRadius, contentsCornerRadiusL),
                                 derivative: ffdx(stubTLowerCornerCircleL, contentsEndCornerL, stubCornerRadius, contentsCornerRadiusL),
                                 transform: cleanup,
                                 x0: CGFloat.pi/4)
            let rAngleU = newton(function: ffx(stubTLowerCornerCircleR, contentsEndCornerR, stubCornerRadius, contentsCornerRadiusR),
                                 derivative: ffdx(stubTLowerCornerCircleR, contentsEndCornerR, stubCornerRadius, contentsCornerRadiusR),
                                 transform: cleanup,
                                 x0: CGFloat.pi/4)
            
//            guard let lAngle = lAngleU else { assert(false); return; }
//            guard let rAngle = rAngleU else { assert(false); return; }
            if let lAngle = lAngleU {
                tempOverflowAngleL = lAngle
            }
            if let rAngle = rAngleU {
                tempOverflowAngleR = rAngle
            }
        }
        
        // QQQ: changing shit around
        do {
            if slopeLCannotCurve {
                slopeAngleL = tempOverflowAngleL
                slopeLStart = circlePoint(c: contentsEndCornerL, r: contentsTStubStartCornerRadius, a: -slopeAngleL + CGFloat.pi)
                slopeLEnd = circlePoint(c: stubTLowerCornerCircleL, r: stubTLowerCornerRadius, a: -slopeAngleL + CGFloat.pi)
            }
            if slopeRCannotCurve {
                slopeAngleR = tempOverflowAngleR
                slopeRStart = circlePoint(c: contentsEndCornerR, r: contentsTStubEndCornerRadius, a: slopeAngleR)
                slopeREnd = circlePoint(c: stubTLowerCornerCircleR, r: stubTLowerCornerRadius, a: slopeAngleR)
            }
        }
        
        print("estimated left angle to corner: \(tempOverflowAngleL * 360.0 / (2 * CGFloat.pi))")
        print("estimated right angle to corner: \(tempOverflowAngleR * 360.0 / (2 * CGFloat.pi))")
        
        let shape = UIBezierPath()
        
        if stage == .expand {
            drawStub: do {
                shape.move(to: CGPoint(x: stubTFrame.maxX - stubTUpperCornerRadius, y: stubTFrame.minY))
                shape.addArc(withCenter: CGPoint(x: stubTFrame.maxX - stubTUpperCornerRadius, y: stubTFrame.minY + stubTUpperCornerRadius),
                             radius: stubTUpperCornerRadius,
                             startAngle: -CGFloat.pi/2,
                             endAngle: 0,
                             clockwise: true)
                shape.addLine(to: CGPoint(x: stubTLowerCornerCircleR.x + stubTLowerCornerRadius, y: stubTLowerCornerCircleR.y))
                shape.addArc(withCenter: stubTLowerCornerCircleR,
                             radius: stubTLowerCornerRadius,
                             startAngle: 0,
                             endAngle: CGFloat.pi/2,
                             clockwise: true)
                shape.addLine(to: CGPoint(x: stubTLowerCornerCircleL.x, y: stubTLowerCornerCircleL.y + stubTLowerCornerRadius))
                shape.addArc(withCenter: stubTLowerCornerCircleL,
                             radius: stubTLowerCornerRadius,
                             startAngle: CGFloat.pi/2,
                             endAngle: CGFloat.pi,
                             clockwise: true)
                shape.addLine(to: CGPoint(x: stubTFrame.minX, y: stubTFrame.minY + stubTUpperCornerRadius))
                shape.addArc(withCenter: CGPoint(x: stubTFrame.minX + stubTUpperCornerRadius, y: stubTFrame.minY + stubTUpperCornerRadius),
                             radius: stubTUpperCornerRadius,
                             startAngle: CGFloat.pi,
                             endAngle: CGFloat.pi * 1.5,
                             clockwise: true)
            }
        }
        else if true { //QQQ: temp corner curve drawing code
            drawShape: do {
                if slopeLCannotCurve {
                    //shape.move(to: slopeLStart)
                    shape.move(to: CGPoint(x: contentsTFrame.minX, y: contentsTFrame.maxY - contentsTStubStartCornerRadius))
                }
                else {
                    shape.move(to: slopeLStartCurveStart)
                    
                    shape.addLine(to: CGPoint(x: contentsTFrame.minX + contentsTStubStartCornerRadius, y: contentsTFrame.maxY))
                    shape.addArc(withCenter: CGPoint(x: contentsTFrame.minX + contentsTStubStartCornerRadius, y: contentsTFrame.maxY - contentsTStubStartCornerRadius),
                                 radius: contentsTStubStartCornerRadius,
                                 startAngle: CGFloat.pi/2,
                                 endAngle: CGFloat.pi,
                                 clockwise: true)
                }
                
                shape.addLine(to: CGPoint(x: contentsTFrame.minX, y: contentsTFrame.minY + contentsTMaxCornerRadius))
                shape.addArc(withCenter: CGPoint(x: contentsTFrame.minX + contentsTMaxCornerRadius, y: contentsTFrame.minY + contentsTMaxCornerRadius),
                             radius: contentsTMaxCornerRadius,
                             startAngle: CGFloat.pi,
                             endAngle: CGFloat.pi * 1.5,
                             clockwise: true)
                shape.addLine(to: CGPoint(x: contentsTFrame.maxX - contentsTMaxCornerRadius, y: contentsTFrame.minY))
                shape.addArc(withCenter: CGPoint(x: contentsTFrame.maxX - contentsTMaxCornerRadius, y: contentsTFrame.minY + contentsTMaxCornerRadius),
                             radius: contentsTMaxCornerRadius,
                             startAngle: -CGFloat.pi/2,
                             endAngle: 0,
                             clockwise: true)
                
                if slopeRCannotCurve {
                    shape.addLine(to: CGPoint(x: contentsTFrame.maxX, y: contentsTFrame.maxY - contentsTStubEndCornerRadius))
                    //shape.addLine(to: slopeRStart)
                }
                else {
                    shape.addLine(to: CGPoint(x: contentsTFrame.maxX, y: contentsTFrame.maxY - contentsTStubEndCornerRadius))
                    shape.addArc(withCenter: CGPoint(x: contentsTFrame.maxX - contentsTStubEndCornerRadius, y: contentsTFrame.maxY - contentsTStubEndCornerRadius),
                                 radius: contentsTStubEndCornerRadius,
                                 startAngle: 0,
                                 endAngle: CGFloat.pi/2,
                                 clockwise: true)
                }
            }
            
            drawStub: do {
                if slopeRCannotCurve {
                    shape.addArc(withCenter: contentsEndCornerR, radius: contentsTStubEndCornerRadius, startAngle: 0, endAngle: slopeAngleR, clockwise: true)
                }
                else {
                    shape.addLine(to: slopeRStartCurveStart)
                    
                    // contents curve R
                    shape.addCurve(to: slopeRStartCurveEnd, controlPoint1: slopeRStart, controlPoint2: slopeRStart)
                }
                
                shape.addLine(to: slopeREnd)
                
                // corner curve R
                shape.addArc(withCenter: stubTLowerCornerCircleR,
                             radius: stubTLowerCornerRadius,
                             startAngle: slopeAngleR,
                             endAngle: CGFloat.pi/2,
                             clockwise: true)
                
                shape.addLine(to: CGPoint(x: stubTLowerCornerCircleL.x, y: stubTLowerCornerCircleL.y + stubTLowerCornerRadius))
                
                // corner curve L
                shape.addArc(withCenter: stubTLowerCornerCircleL,
                             radius: stubTLowerCornerRadius,
                             startAngle: CGFloat.pi/2,
                             endAngle: CGFloat.pi/2 + (CGFloat.pi/2 - slopeAngleL),
                             clockwise: true)
                
                if slopeLCannotCurve {
                    shape.addLine(to: slopeLStart)
                    shape.addArc(withCenter: contentsEndCornerL, radius: contentsTStubStartCornerRadius, startAngle: CGFloat.pi - slopeAngleR, endAngle: CGFloat.pi, clockwise: true)
                }
                else {
                    shape.addLine(to: slopeLStartCurveEnd)
                    
                    // contents curve L
                    shape.addCurve(to: slopeLStartCurveStart, controlPoint1: slopeLStart, controlPoint2: slopeLStart)
                }
            }
        }
        else { // original
            drawShape: do {
                if slopeLCannotCurve {
                    shape.move(to: CGPoint(x: contentsTFrame.minX, y: contentsTFrame.maxY))
                }
                else {
                    shape.move(to: slopeLStartCurveStart)
                    
                    shape.addLine(to: CGPoint(x: contentsTFrame.minX + contentsTStubStartCornerRadius, y: contentsTFrame.maxY))
                    shape.addArc(withCenter: CGPoint(x: contentsTFrame.minX + contentsTStubStartCornerRadius, y: contentsTFrame.maxY - contentsTStubStartCornerRadius),
                                 radius: contentsTStubStartCornerRadius,
                                 startAngle: CGFloat.pi/2,
                                 endAngle: CGFloat.pi,
                                 clockwise: true)
                }
                
                shape.addLine(to: CGPoint(x: contentsTFrame.minX, y: contentsTFrame.minY + contentsTMaxCornerRadius))
                shape.addArc(withCenter: CGPoint(x: contentsTFrame.minX + contentsTMaxCornerRadius, y: contentsTFrame.minY + contentsTMaxCornerRadius),
                             radius: contentsTMaxCornerRadius,
                             startAngle: CGFloat.pi,
                             endAngle: CGFloat.pi * 1.5,
                             clockwise: true)
                shape.addLine(to: CGPoint(x: contentsTFrame.maxX - contentsTMaxCornerRadius, y: contentsTFrame.minY))
                shape.addArc(withCenter: CGPoint(x: contentsTFrame.maxX - contentsTMaxCornerRadius, y: contentsTFrame.minY + contentsTMaxCornerRadius),
                             radius: contentsTMaxCornerRadius,
                             startAngle: -CGFloat.pi/2,
                             endAngle: 0,
                             clockwise: true)
                
                if slopeRCannotCurve {
                    shape.addLine(to: CGPoint(x: contentsTFrame.maxX, y: contentsTFrame.maxY))
                }
                else {
                    shape.addLine(to: CGPoint(x: contentsTFrame.maxX, y: contentsTFrame.maxY - contentsTStubEndCornerRadius))
                    shape.addArc(withCenter: CGPoint(x: contentsTFrame.maxX - contentsTStubEndCornerRadius, y: contentsTFrame.maxY - contentsTStubEndCornerRadius),
                                 radius: contentsTStubEndCornerRadius,
                                 startAngle: 0,
                                 endAngle: CGFloat.pi/2,
                                 clockwise: true)
                }
            }
            
            drawStub: do {
                if slopeRCannotCurve {
                    // do nothing
                }
                else {
                    shape.addLine(to: slopeRStartCurveStart)
                    
                    // contents curve R
                    shape.addCurve(to: slopeRStartCurveEnd, controlPoint1: slopeRStart, controlPoint2: slopeRStart)
                }
                
                shape.addLine(to: slopeREnd)
                
                // corner curve R
                shape.addArc(withCenter: stubTLowerCornerCircleR,
                             radius: stubTLowerCornerRadius,
                             startAngle: slopeAngleR,
                             endAngle: CGFloat.pi/2,
                             clockwise: true)
                
                shape.addLine(to: CGPoint(x: stubTLowerCornerCircleL.x, y: stubTLowerCornerCircleL.y + stubTLowerCornerRadius))
                
                // corner curve L
                shape.addArc(withCenter: stubTLowerCornerCircleL,
                             radius: stubTLowerCornerRadius,
                             startAngle: CGFloat.pi/2,
                             endAngle: CGFloat.pi/2 + (CGFloat.pi/2 - slopeAngleL),
                             clockwise: true)
                
                if slopeLCannotCurve {
                    // do nothing
                }
                else {
                    shape.addLine(to: slopeLStartCurveEnd)
                    
                    // contents curve L
                    shape.addCurve(to: slopeLStartCurveStart, controlPoint1: slopeLStart, controlPoint2: slopeLStart)
                }
            }
        }
        
        shape.close()
        
        //addCircle(shape, c: slopeRStartCurveStart, r: 5)
        //addCircle(shape, c: slopeRStart, r: 5)
        //addCircle(shape, c: slopeRStartCurveEnd, r: 5)
        //addCircle(shape, c: slopeLStartCurveStart, r: 5)
        //addCircle(shape, c: slopeLStart, r: 5)
        //addCircle(shape, c: slopeLStartCurveEnd, r: 5)
        
        self.shape.shape = shape
        
        // KLUDGE: this belongs elsewhere, but we don't have access to contentsExpandT outside of this method
        fancyEffects: do {
            let t = contentsExpandT
            let translate = CGAffineTransform(translationX: 0, y: 60 + t * -60)
            let scale = CGAffineTransform(scaleX: 1, y: 1)
            let transform = translate.concatenating(scale)
            self.title.transform = transform
            self.selectionViewContainer.transform = transform
            self.contentsContainer.alpha = contentsExpandT
        }
    }
}

// layout
extension SelectionPopup {
    // expanded stub size
    func calculateStubSize() -> CGSize {
        let vertical = (anchorPosition.side == 0 || anchorPosition.side == 2)
        
        if vertical {
            return CGSize(width: SelectionPopup.stubFullSize.width, height: SelectionPopup.stubFullSize.height)
        }
        else {
            return CGSize(width: SelectionPopup.stubFullSize.height, height: SelectionPopup.stubFullSize.width)
        }
    }
    
    // expanded stub frame
    func calculateStubFrame(boundingBox: CGSize) -> CGRect {
        assert(anchorPosition.side < 4 && anchorPosition.side >= 0)
        assert(anchorPosition.position >= 0 && anchorPosition.position <= 1)
        
        let vertical = (anchorPosition.side == 0 || anchorPosition.side == 2)
        
        var stubFrame: CGRect = CGRect.zero
        
        stubFrame.size = calculateStubSize()
        
        if anchorPosition.side == 0 { //top
            stubFrame.origin = CGPoint(x: (boundingBox.width * anchorPosition.position) - stubFrame.size.width/2, y: 0)
        }
        else if anchorPosition.side == 1 { //left
            stubFrame.origin = CGPoint(x: 0, y: (boundingBox.height * (1 - anchorPosition.position)) - stubFrame.size.height/2)
        }
        else if anchorPosition.side == 2 { //bottom
            stubFrame.origin = CGPoint(x: (boundingBox.width * anchorPosition.position) - stubFrame.size.width/2, y: boundingBox.height - stubFrame.size.height)
        }
        else { //right
            stubFrame.origin = CGPoint(x: boundingBox.width - stubFrame.size.width, y: (boundingBox.height * (1 - anchorPosition.position)) - stubFrame.size.height/2)
        }
        
        if vertical {
            stubFrame.origin = CGPoint(x: max(min(stubFrame.origin.x, boundingBox.width - stubFrame.size.width), 0), y: stubFrame.origin.y)
        }
        else {
            stubFrame.origin = CGPoint(x: stubFrame.origin.x, y: max(min(stubFrame.origin.y, boundingBox.height - stubFrame.size.height), 0))
        }
        
        return stubFrame
    }
    
    func calculateFrames() -> (boundingBox: CGSize, stub: CGRect, contentsContainer: CGRect, title: CGRect, selectionContainer: CGRect) {
        // KLUDGE:
        let selectionViewContainerTransform = self.selectionViewContainer.transform
        let titleTransform = self.title.transform
        self.selectionViewContainer.transform = CGAffineTransform.identity
        self.title.transform = CGAffineTransform.identity
        
        var boundingBox: CGSize
        let stubFrame: CGRect
        var contentsContainerFrame = CGRect.zero
        var titleFrame = CGRect.zero
        var selectionContainerFrame = CGRect.zero
        
        let margin = itemMargin
        
        let selectionViewLayout = calculateSelectionViewLayout()
        let stubSize = calculateStubSize()
        let stubVertical = (anchorPosition.side == 0 || anchorPosition.side == 2)
        let titleSize = self.title.sizeThatFits(CGSize(width: CGFloat.infinity, height: CGFloat.infinity))
        
        layoutViews: do {
            selectionContainerFrame.size = selectionViewLayout.boundingBox
            
            titleFrame.size = titleSize
            
            contentsContainerFrame.size = CGSize(
                width: margin + selectionContainerFrame.size.width + margin,
                height: margin + titleFrame.size.height + margin + selectionContainerFrame.size.height + margin)
            
            // container can't be smaller than maximally expanded stub or title
            if stubVertical {
                contentsContainerFrame.size.width = max(contentsContainerFrame.width, stubSize.width * SelectionPopup.minimumContentsMultiplierAlongStubAxis)
                contentsContainerFrame.size.width = max(contentsContainerFrame.width, margin + titleFrame.size.width + margin)
            }
            else {
                contentsContainerFrame.size.height = max(contentsContainerFrame.height, stubSize.height * SelectionPopup.minimumContentsMultiplierAlongStubAxis)
            }
            
            titleFrame.origin = CGPoint(x: contentsContainerFrame.width/2 - titleFrame.size.width/2,
                                        y: margin)
            
            selectionContainerFrame.origin = CGPoint(x: contentsContainerFrame.width/2 - selectionContainerFrame.size.width/2,
                                                     y: titleFrame.maxY + margin)
            
            if stubVertical {
                boundingBox = CGSize(width: contentsContainerFrame.size.width,
                                     height: contentsContainerFrame.size.height + stubSize.height)
            }
            else {
                boundingBox = CGSize(width: contentsContainerFrame.size.width + stubSize.width,
                                     height: contentsContainerFrame.size.height)
            }
            
            stubFrame = calculateStubFrame(boundingBox: boundingBox)
            
            if anchorPosition.side == 0 {
                contentsContainerFrame.origin = CGPoint(x: 0, y: stubFrame.size.height)
            }
            else if anchorPosition.side == 1 {
                contentsContainerFrame.origin = CGPoint(x: stubFrame.size.width, y: 0)
            }
        }
        
        // KLUDGE:
        self.selectionViewContainer.transform = selectionViewContainerTransform
        self.title.transform = titleTransform
        
        return (boundingBox, stubFrame, contentsContainerFrame, titleFrame, selectionContainerFrame)
    }
    
    func calculateSelectionViewLayout() -> (boundingBox: CGSize, items: [CGRect]) {
        assert(self.selectionViews.count != 0)
        
        // TODO: perhaps it would be better to pack views into rows based on their widths... but, eh, most will be
        // the same size anyway, so why bother?
        
        let rows = Int(ceil(Double(self.selectionViews.count) / Double(maxItemsPerRow)))
        let rowHeight = itemHeight + itemSelectorMargin * 2
        
        var rowWidths: [CGFloat] = []
        calculateRowWidths: do {
            for r in 0..<rows {
                var currentRowWidth: CGFloat = 0
                
                for rowItem in 0..<maxItemsPerRow {
                    let itemIndex = r * maxItemsPerRow + rowItem
                    
                    if itemIndex < self.selectionViews.count {
                        let view = self.selectionViews[itemIndex].view
                        let selectorScaledWidth = (view.bounds.size.width / view.bounds.size.height) * itemHeight + itemSelectorMargin * 2
                        
                        currentRowWidth += selectorScaledWidth
                        
                        if rowItem != 0 {
                            currentRowWidth += itemMargin
                        }
                    }
                }
                
                rowWidths.append(currentRowWidth)
                
                currentRowWidth = 0
            }
        }
        
        guard let maxRowWidth: CGFloat = rowWidths.max() else {
            assert(false, "could not find max row width")
            return (CGSize.zero, [])
        }
        
        var items: [CGRect] = []
        calculateItemFrames: do {
            for (r, rowWidth) in rowWidths.enumerated() {
                let margin = (maxRowWidth - rowWidth) / 2.0
                var coveredRowWidth: CGFloat = 0
                
                for rowItem in 0..<maxItemsPerRow {
                    let itemIndex = r * maxItemsPerRow + rowItem
                    
                    if itemIndex < self.selectionViews.count {
                        let view = self.selectionViews[itemIndex].view
                        let selectorScaledWidth = (view.bounds.size.width / view.bounds.size.height) * itemHeight + itemSelectorMargin * 2
                        
                        let viewFrame = CGRect(x: margin + coveredRowWidth,
                                               y: CGFloat(r) * rowHeight + CGFloat(r) * itemMargin,
                                               width: selectorScaledWidth,
                                               height: rowHeight)
                        items.append(viewFrame)
                        
                        coveredRowWidth += (selectorScaledWidth + itemMargin)
                    }
                }
                
                coveredRowWidth = 0
            }
        }
        
        let totalSize = CGSize(width: maxRowWidth,
                               height: rowHeight * CGFloat(rows) + itemMargin * CGFloat(max(rows - 1, 0)))
        
        return (totalSize, items)
    }
}

// MARK: - Helpers -

fileprivate func fmodpos(a: CGFloat, b: CGFloat) -> CGFloat {
    return a - b * floor(a / b)
}

fileprivate func newton(
    function: (CGFloat)->CGFloat,
    derivative: (CGFloat)->CGFloat,
    transform: ((CGFloat)->CGFloat)? = nil, //if root is wrong, maybe massage it to get actual desired root?
    x0: CGFloat, //initial estimate
    tolerance: Int = 5, //accuracy digits
    maxIterations: UInt = 15) -> CGFloat?
{
    var x = x0
    let tolerance = pow(10, -CGFloat(tolerance))
    let epsilon = pow(10, -CGFloat(14))
    
    for _ in 0..<maxIterations {
        let fx = function(x)
        let fdx = derivative(x)
        
        if abs(fdx) < epsilon {
            return nil //divide by zero
        }
        
        let prevX = x
        x = x - fx / fdx
        
        if abs(x - prevX) <= tolerance * abs(x) {
            if let transform = transform { return transform(x) }
            else { return x }
        }
    }
    
    return nil
}

// MARK: - Helper Classes -

class BezierBackgroundView: UIView {
    public var shape: UIBezierPath { didSet { shapeDidSet(oldValue) } }
    public var color: UIColor { didSet { colorDidSet(oldValue) } }
    
    func shapeDidSet(_ oldValue: UIBezierPath) {
        self.layerShape.path = self.shape.cgPath
    }
    func colorDidSet(_ oldValue: UIColor) {
        self.layerShape.fillColor = self.color.cgColor
    }
    
    override class var layerClass: Swift.AnyClass {
        get {
            return CAShapeLayer.self
        }
    }
    
    var layerShape: CAShapeLayer {
        get {
            return (self.layer as! CAShapeLayer)
        }
    }
    
    override init(frame: CGRect) {
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
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SimpleMovementGestureRecognizerTwo: UIGestureRecognizer {
    private var firstTouch: UITouch?
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if self.state == .possible, self.firstTouch == nil, let touch = touches.first {
            self.firstTouch = touch
            self.state = .began
        }
        
        if self.firstTouch != nil {
            for touch in touches {
                if touch != self.firstTouch {
                    self.ignore(touch, for: event)
                }
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        if let touch = self.firstTouch, touches.contains(touch) {
            self.state = .changed
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        if let touch = self.firstTouch, touches.contains(touch) {
            self.firstTouch = nil
            self.state = .ended
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        if let touch = self.firstTouch, touches.contains(touch) {
            self.firstTouch = nil
            self.state = .cancelled
        }
    }
}
