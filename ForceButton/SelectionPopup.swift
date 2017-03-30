import UIKit
import UIKit.UIGestureRecognizerSubclass

fileprivate let UIArbitraryStartingFrame = CGRect(x: 0, y: 0, width: 100, height: 100)

fileprivate let stubAngle: CGFloat = 20
fileprivate let stubSlopeContentsBezierRadius: CGFloat = 32
fileprivate let qqqStubCompactSize = CGSize(width: 62.5 - 3, height: 60)
fileprivate let qqqStubExpandedInsetSize = CGSize(width: 16, height: 16)
fileprivate let qqqStubFullSize = CGSize(width: qqqStubCompactSize.width + qqqStubExpandedInsetSize.width * 2,
                                         height: qqqStubCompactSize.height + qqqStubExpandedInsetSize.height * 2)

// NEXT: arc connection formula
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
    static let minimumPopupStubMultiplierAlongStubAxis: CGFloat = 1.5
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
    // NEXT: 0.3, 0, same with opposite side
    var anchorPosition: (side: Int, position: CGFloat) = (2, 0.5) { //t,l,b,r -- +x,+y axis aligned (CG coords)
        didSet { sizeToFit() }
    }
    var anchorFrame: CGRect {
        get {
            sizeToFit()
            let stubFrame = calculateStubFrame(boundingBox: self.bounds.size)
            return stubFrame
        }
    }
    
    // procedural properties
    var t: Double = 0 {
        didSet {
            let stubFrame = calculateStubFrame(boundingBox: self.bounds.size)
            generateShape(stubFrame: stubFrame)
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
        
        //contentsContainer.backgroundColor = UIColor.blue
        //selectionViewContainer.backgroundColor = UIColor.yellow
        //title.backgroundColor = UIColor.brown
        
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
    
    func generateShape(stubFrame: CGRect) {
        enum Stage {
            case expand
            case bloom
        }
        
        func easeOutCubic(_ t: CGFloat) -> CGFloat {
            return max(min(1 - pow(1 - t, 3), 1), 0)
        }
        
        func addCircle(_ shape: UIBezierPath, c: CGPoint, r: CGFloat) {
            shape.close()
            shape.move(to: CGPoint(x: c.x + r, y: c.x))
            shape.addArc(withCenter: c, radius: r, startAngle: 0, endAngle: CGFloat.pi, clockwise: true)
            shape.addArc(withCenter: c, radius: r, startAngle: CGFloat.pi, endAngle: 0, clockwise: true)
            shape.close()
        }
        
        // fixed top-level properties
        let stubExpandedInsetSize = qqqStubExpandedInsetSize
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
        let contentsCornerRadius: CGFloat = 12
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
        let stubTInclineMaxAngleRadians = (stubAngle * stubSlopeT) * ((2 * CGFloat.pi) / 360.0)
        
        let slopeLFarthestPossibleT: CGFloat
        let slopeRFarthestPossibleT: CGFloat
        
        calculateMaxSlopeExtent: do {
            let stubEndFrame = stubFrame
            
            let slopeLFarthestPossibleXPointWithoutBezier = contentsCornerRadius
            let slopeRFarthestPossibleXPointWithoutBezier = contentsSize.width - contentsCornerRadius
            
            distanceApproximation: do {
                let baseBezierRadius = stubSlopeContentsBezierRadius
                let baseAngle = stubAngle * ((2 * CGFloat.pi) / 360.0)
                let maxXDistanceR = slopeRFarthestPossibleXPointWithoutBezier - stubEndFrame.maxX
                let maxXDistanceL = -slopeLFarthestPossibleXPointWithoutBezier + stubEndFrame.minX
                let height = stubEndFrame.height
                let aL = maxXDistanceL/height
                let aR = maxXDistanceR/height
                let b = baseBezierRadius/(baseAngle*height)
                
                let ffx = { (a: CGFloat, b: CGFloat)->((CGFloat)->CGFloat) in
                    return { (angle: CGFloat) -> CGFloat in
                        return a - b*angle - tan(angle)
                    }
                }
                let ffdx = { (a: CGFloat, b: CGFloat)->((CGFloat)->CGFloat) in
                    return { (angle: CGFloat) -> CGFloat in
                        return -b - pow(1/cos(angle), 2)
                    }
                }
                
                let angleL = newton(function: ffx(aL, b), derivative: ffdx(aL, b), x0: CGFloat.pi/4, iterations: 10)
                let angleR = newton(function: ffx(aR, b), derivative: ffdx(aR, b), x0: CGFloat.pi/4, iterations: 10)
                slopeLFarthestPossibleT = angleL/baseAngle
                slopeRFarthestPossibleT = angleR/baseAngle
                
                // NEXT: clamp
                // NEXT: avoid divide by 0 & use epsilon
                assert(angleL >= 0 && angleL <= CGFloat.pi/2)
                assert(angleR >= 0 && angleR <= CGFloat.pi/2)
                
                print("approximate angle L: \(angleL * (360.0 / (2 * CGFloat.pi))), t: \(slopeLFarthestPossibleT)")
                print("approximate angle R: \(angleR * (360.0 / (2 * CGFloat.pi))), t: \(slopeRFarthestPossibleT)")
            }
        }
        
        let slopeLCannotCurve = slopeLFarthestPossibleT < minStubSlopeClampedT
        let slopeRCannotCurve = slopeRFarthestPossibleT < minStubSlopeClampedT
        
        // stub corner/slope key properties
        // no need to add pi/2 b/c measured from right, not from top
        // end = connection to lower circle, start = connection to contents box
        let stubTLowerCornerCircleL = CGPoint(x: stubTFrame.minX + stubTLowerCornerRadius, y: stubTFrame.maxY - stubTLowerCornerRadius)
        let stubTLowerCornerCircleR = CGPoint(x: stubTFrame.maxX - stubTLowerCornerRadius, y: stubTFrame.maxY - stubTLowerCornerRadius)
        let slopeRFarthestXPoint = contentsSize.width - contentsCornerRadius - stubSlopeContentsBezierRadius
        let slopeLFarthestXPoint = contentsCornerRadius + stubSlopeContentsBezierRadius
        let slopeMaxAngleR = atan((slopeRFarthestXPoint - stubFrame.maxX) / stubFrame.size.height)
        let slopeMaxAngleL = atan((-slopeLFarthestXPoint + stubFrame.minX) / stubFrame.size.height)
        let slopeAngleL = max(min(stubTInclineMaxAngleRadians, slopeMaxAngleL), 0)
        let slopeAngleR = max(min(stubTInclineMaxAngleRadians, slopeMaxAngleR), 0)
        let slopeAngleLT = (stubTInclineMaxAngleRadians == 0 ? 0 : slopeAngleL/stubTInclineMaxAngleRadians)
        let slopeAngleRT = (stubTInclineMaxAngleRadians == 0 ? 0 : slopeAngleR/stubTInclineMaxAngleRadians)
        let slopeLEnd = CGPoint(x: stubTLowerCornerCircleL.x + stubTLowerCornerRadius * cos(-slopeAngleL + CGFloat.pi),
                                y: stubTLowerCornerCircleL.y + stubTLowerCornerRadius * sin(-slopeAngleL + CGFloat.pi))
        let slopeREnd = CGPoint(x: stubTLowerCornerCircleR.x + stubTLowerCornerRadius * cos(slopeAngleR),
                                y: stubTLowerCornerCircleR.y + stubTLowerCornerRadius * sin(slopeAngleR))
        let slopeLHeight = slopeLEnd.y - stubTFrame.minY
        let slopeRHeight = slopeREnd.y - stubTFrame.minY
        let slopeLWidth = slopeLHeight * tan(slopeAngleL)
        let slopeRWidth = slopeRHeight * tan(slopeAngleR)
        let slopeLStart = CGPoint(x: slopeLEnd.x - slopeLWidth, y: slopeLEnd.y - slopeLHeight)
        let slopeRStart = CGPoint(x: slopeREnd.x + slopeRWidth, y: slopeREnd.y - slopeRHeight)
        
        // more interpolated properties
        let  minStubSlopeContentsBezierRadiusT: CGFloat = 0.3
        let stubTSlopeContentsBezierRadiusL = stubSlopeContentsBezierRadius * max(min(stubSlopeT, slopeAngleLT), (stage == .bloom ? minStubSlopeContentsBezierRadiusT : 0))
        let stubTSlopeContentsBezierRadiusR = stubSlopeContentsBezierRadius * max(min(stubSlopeT, slopeAngleRT), (stage == .bloom ? minStubSlopeContentsBezierRadiusT : 0))
        
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
        let slopeLStartCurveStart = CGPoint(x: slopeLStart.x - stubTSlopeContentsBezierRadiusL, y: slopeLStart.y)
        let slopeRStartCurveStart = CGPoint(x: slopeRStart.x + stubTSlopeContentsBezierRadiusR, y: slopeRStart.y)
        let slopeLStartCurveEnd = CGPoint(x: slopeLEnd.x + slopeLVector.x - slopeLVectorUpperRadius.x,
                                          y: slopeLEnd.y + slopeLVector.y - slopeLVectorUpperRadius.y)
        let slopeRStartCurveEnd = CGPoint(x: slopeREnd.x + slopeRVector.x - slopeRVectorUpperRadius.x,
                                          y: slopeREnd.y + slopeRVector.y - slopeRVectorUpperRadius.y)
        
        // contents frame
        let contentsMinWidth = max(0, slopeRStartCurveStart.x - slopeLStartCurveStart.x)
        let contentsMinHeight = CGFloat(0)
        let contentsTSize = CGSize(width: contentsMinWidth + contentsExpandT * (contentsSize.width - contentsMinWidth),
                                   height: contentsMinHeight + contentsExpandT * (contentsSize.height - contentsMinHeight))
        let contentsTFrame = CGRect(x: min(max(stubTFrame.midX - contentsTSize.width / 2.0, 0), contentsSize.width - contentsTSize.width),
                                    y: stubTFrame.minY - contentsTSize.height,
                                    width: contentsTSize.width,
                                    height: contentsTSize.height)
        
        // contents corners
        let contentsTStubStartOverhang = slopeLStartCurveStart.x - contentsTFrame.minX
        let contentsTStubEndOverhang = -slopeRStartCurveStart.x + contentsTFrame.maxX
        let contentsTMaxCornerRadius = min(contentsTFrame.size.height/2, contentsCornerRadius)
        let contentsTStubStartCornerRadius = min(contentsTMaxCornerRadius, contentsTStubStartOverhang)
        let contentsTStubEndCornerRadius = min(contentsTMaxCornerRadius, contentsTStubEndOverhang)
        
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
        else {
            drawShape: do {
                shape.move(to: slopeLStartCurveStart)
                
                shape.addLine(to: CGPoint(x: contentsTFrame.minX + contentsTStubStartCornerRadius, y: contentsTFrame.maxY))
                shape.addArc(withCenter: CGPoint(x: contentsTFrame.minX + contentsTStubStartCornerRadius, y: contentsTFrame.maxY - contentsTStubStartCornerRadius),
                             radius: contentsTStubStartCornerRadius,
                             startAngle: CGFloat.pi/2,
                             endAngle: CGFloat.pi,
                             clockwise: true)
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
                shape.addLine(to: CGPoint(x: contentsTFrame.maxX, y: contentsTFrame.maxY - contentsTStubEndCornerRadius))
                shape.addArc(withCenter: CGPoint(x: contentsTFrame.maxX - contentsTStubEndCornerRadius, y: contentsTFrame.maxY - contentsTStubEndCornerRadius),
                             radius: contentsTStubEndCornerRadius,
                             startAngle: 0,
                             endAngle: CGFloat.pi/2,
                             clockwise: true)
                
                shape.addLine(to: slopeRStartCurveStart)
            }
            
            drawStub: do {
                // contents curve R
                shape.addCurve(to: slopeRStartCurveEnd, controlPoint1: slopeRStart, controlPoint2: slopeRStart)
                
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
                
                shape.addLine(to: slopeLStartCurveEnd)
                
                // contents curve L
                shape.addCurve(to: slopeLStartCurveStart, controlPoint1: slopeLStart, controlPoint2: slopeLStart)
            }
        }
        
        shape.close()
        
//        addCircle(shape, c: slopeRStartCurveStart, r: 5)
//        addCircle(shape, c: slopeRStart, r: 5)
//        addCircle(shape, c: slopeRStartCurveEnd, r: 5)
//        addCircle(shape, c: slopeLStartCurveStart, r: 5)
//        addCircle(shape, c: slopeLStart, r: 5)
//        addCircle(shape, c: slopeLStartCurveEnd, r: 5)
        
        // KLUDGE: fancy contents effects
        // TODO: disable interaction
        let mask = CAShapeLayer()
        mask.frame = self.shape.bounds
        mask.path = shape.cgPath
        self.contentsContainer.layer.mask = mask
        let t = contentsExpandT
        let translate = CGAffineTransform(translationX: 0, y: 60 + t * -60)
        let scale = CGAffineTransform(scaleX: 1, y: 1)
        let transform = translate.concatenating(scale)
        self.title.transform = transform
        self.selectionViewContainer.transform = transform
        self.contentsContainer.alpha = contentsExpandT
        
        self.shape.shape = shape
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let layout = calculateFrames()
        
        return CGSize(width: layout.boundingBox.width, height: layout.boundingBox.height)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

// layout
extension SelectionPopup {
    // expanded stub size
    func calculateStubSize() -> CGSize {
        let vertical = (anchorPosition.side == 0 || anchorPosition.side == 2)
        
        if vertical {
            return CGSize(width: qqqStubFullSize.width, height: qqqStubFullSize.height)
        }
        else {
            return CGSize(width: qqqStubFullSize.height, height: qqqStubFullSize.width)
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
                contentsContainerFrame.size.width = max(contentsContainerFrame.width, stubSize.width * SelectionPopup.minimumPopupStubMultiplierAlongStubAxis)
                contentsContainerFrame.size.width = max(contentsContainerFrame.width, margin + titleFrame.size.width + margin)
            }
            else {
                contentsContainerFrame.size.height = max(contentsContainerFrame.height, stubSize.height * SelectionPopup.minimumPopupStubMultiplierAlongStubAxis)
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

// assuming functions are contiguous within range
func newton(function: (CGFloat)->CGFloat, derivative: (CGFloat)->CGFloat, x0: CGFloat, iterations: UInt) -> CGFloat {
    var x = x0
    var error: CGFloat?
    
    for _ in 0..<iterations {
        let prevX = x
        x = prevX - function(prevX) / derivative(prevX)
        error = x - prevX
    }
   
    if let error = error {
        print("error is \(String(format: "%.10f", error))")
    }
    
    return x
}

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
