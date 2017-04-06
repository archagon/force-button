import UIKit
import UIKit.UIGestureRecognizerSubclass

fileprivate let UIArbitraryStartingFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
fileprivate let DebugDraw = false

// TODO: 2x horizontal

public protocol SelectionPopupDelegate {
}

public class SelectionPopup: UIView, UIGestureRecognizerDelegate {
    // MARK: Properties
    
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
    
    private func relayout() { sizeToFit(); setNeedsLayout(); }

    // layout properties
    public var itemHeight: CGFloat = 44 { //AB: assuming that width is reasonably close to height
        didSet { relayout() }
    }
    public var itemSelectorMargin: CGFloat = 8 {
        didSet { relayout() }
    }
    public var itemMargin: CGFloat = 4 {
        didSet { relayout() }
    }
    public var maxItemsPerRow: Int = 4 {
        didSet { relayout() }
    }
    public var contentInset: UIEdgeInsets = UIEdgeInsets.zero {
        didSet { relayout() }
    }
    
    // nitty-gritty layout properties
    public var maximumAnchorSlopeAngle: CGFloat = 20 {
        didSet { relayout() }
    }
    public var maximumAnchorSlopeBezierRadius: CGFloat = 32 {
        didSet { relayout() }
    }
    public var minimumContentsMultiplierAlongAnchorAxis: CGFloat = 1.2 {
        didSet { relayout() }
    }
    
    // anchor properties
    public var anchorCompactSize: CGSize = CGSize(width: 62.5 - 3, height: 60) {
        didSet { relayout() }
    }
    public var anchorExpandedInset: CGSize = CGSize(width: 16, height: 16) {
        didSet { relayout() }
    }
    public var anchorPosition: (side: Int, position: CGFloat) = (2, 0.5) { //t,l,b,r -- +x,+y axis aligned (CG coords)
        didSet { relayout() }
    }
    public var anchorFrame: CGRect {
        get {
            sizeToFit()
            let stubFrame = calculateStubFrame(boundingBox: self.bounds.size)
            return stubFrame
        }
    }
    public var contentsFrame: CGRect {
        get {
            sizeToFit()
            return self.contentsContainer.frame
        }
    }
    
    // generated layout properties
    var anchorExpandedSize: CGSize {
        get {
            return CGSize(width: anchorCompactSize.width + anchorExpandedInset.width * 2,
                          height: anchorCompactSize.height + anchorExpandedInset.height * 2)
        }
    }
    public var currentShape: UIBezierPath {
        get {
            return self.shape.shape
        }
    }
    
    // procedural properties -- 0 to 0.5 is expand, while 0.5 to 1 is popup
    public var t: Double = 0 {
        didSet {
            let stubFrame = calculateStubFrame(boundingBox: self.bounds.size)
            generateShape(stubFrame: stubFrame)
            
            //self.gestureRecognizers!.first!.isEnabled = (t == 1)
            
            if self.maskContainer.layer.mask == nil {
                let mask = CAShapeLayer()
                self.maskContainer.layer.mask = mask
            }
            let mask = self.maskContainer.layer.mask as! CAShapeLayer
            mask.frame = self.shape.bounds
            
            let maskShape = self.shape.shape
            mask.path = maskShape.cgPath
        }
    }
    
    // views
    var shape: BezierBackgroundView
    var debugLayer: UIView?
    var maskContainer: UIView
    var contentsContainer: UIView
    var selectionViewContainer: UIView
    var title: UILabel
    var selectionViews: [(selectionBox: UIView, view: UIView)] = []
    
    // hardware stuff
    var selectionFeedback: UISelectionFeedbackGenerator
    
    // MARK: Lifecycle
    
    override public init(frame: CGRect) {
        self.previousSize = CGSize.zero
        
        let shape = BezierBackgroundView(frame: UIArbitraryStartingFrame)
        let maskContainer = UIView(frame: UIArbitraryStartingFrame)
        let contentsContainer = UIView(frame: UIArbitraryStartingFrame)
        let selectionViewContainer = UIView(frame: UIArbitraryStartingFrame)
        let title = UILabel()
        
        self.shape = shape
        self.maskContainer = maskContainer
        self.contentsContainer = contentsContainer
        self.selectionViewContainer = selectionViewContainer
        self.title = title
        
        self.selectionFeedback = UISelectionFeedbackGenerator()
        
        if DebugDraw {
            self.debugLayer = UIView()
        }
        
        super.init(frame: frame)
        
        //self.backgroundColor = UIColor.yellow.withAlphaComponent(0.25)
        
        self.clipsToBounds = true
        
        viewLayoutSetup: do {
            self.addSubview(shape)
            if let debugLayer = self.debugLayer { self.addSubview(debugLayer) }
            self.addSubview(maskContainer)
            maskContainer.addSubview(contentsContainer)
            contentsContainer.addSubview(selectionViewContainer)
            contentsContainer.addSubview(title)
        }
        
        viewAppearanceSetup: do {
            title.text = "Generic Popup"
            title.textColor = UIColor.white
            title.textAlignment = .center
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
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
    
    public func changeSelection(_ withWorldPosition: CGPoint) {
        let touch = self.convert(withWorldPosition, from: nil)
        
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
        
        let item = findClosestItem(position: touch)
        
        self.selectionFeedback.prepare()
        self.selectedItem = item
    }
    
    public func cancel() {
        guard let gestures = self.gestureRecognizers else {
            return
        }
        
        for gesture in gestures {
            gesture.cancel()
        }
    }
    
    func tappedItem(button: UIButton) {
        self.selectedItem = button.tag
    }
    
    // MARK: Gestures
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    // MARK: Layout
    
    override public func setNeedsLayout() {
        previousSize = nil
        
        super.setNeedsLayout()
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        //if previousSize == nil || self.bounds.size != previousSize! {
        if true {
            print("laying out subviews")
        
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
                
                self.maskContainer.frame = self.bounds
                self.shape.frame = self.bounds
                self.debugLayer?.frame = self.bounds
            }
            
            // KLUDGE:
            self.selectionViewContainer.transform = selectionViewContainerTransform
            self.title.transform = titleTransform
            
            generateShape(stubFrame: layout.stub)
            
            previousSize = self.bounds.size
        }
    }
    var previousSize: CGSize?
    
    override public func sizeThatFits(_ size: CGSize) -> CGSize {
        let layout = calculateFrames()
        
        return CGSize(width: layout.boundingBox.width, height: layout.boundingBox.height)
    }
    
    // MARK: Drawing
    
    func generateShape(stubFrame: CGRect) {
        enum Stage {
            case expand
            case bloom
        }
        
        // helpers
        func fmodpos(a: CGFloat, b: CGFloat) -> CGFloat {
            return a - b * floor(a / b)
        }
        func circlePoint(c: CGPoint, r: CGFloat, a: CGFloat, clockwise: Bool) -> CGPoint {
            return CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(clockwise ? a : -a))
        }
        func addCircle(_ shape: UIBezierPath, c: CGPoint, r: CGFloat) {
            shape.close()
            shape.move(to: CGPoint(x: c.x + r, y: c.x))
            shape.addArc(withCenter: c, radius: r, startAngle: 0, endAngle: CGFloat.pi, clockwise: true)
            shape.addArc(withCenter: c, radius: r, startAngle: CGFloat.pi, endAngle: 0, clockwise: true)
            shape.close()
        }
        
        // fixed top-level properties
        let stubFullInsetSize = anchorExpandedInset
        let maximumSlopeBezierRadius = maximumAnchorSlopeBezierRadius
        let maximumSlopeAngle = maximumAnchorSlopeAngle
        let contentsSize = self.contentsContainer.bounds.size
        let t = CGFloat(self.t)
        let side = self.anchorPosition.side
        let clockwise = (side == 2 || side == 3)
        
        // fixed t ranges
        let stubExpandTRange: ClosedRange<CGFloat> = CGFloat(0.0)...CGFloat(0.5)
        let stubRemoveTopCornersTRange: ClosedRange<CGFloat> = CGFloat(stubExpandTRange.upperBound)...CGFloat(stubExpandTRange.upperBound + 0.05)
        let stubSlopeTRange: ClosedRange<CGFloat> = CGFloat(stubRemoveTopCornersTRange.upperBound)...CGFloat(1)
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
        var stubExpandedT = min(max((t - stubExpandTRange.lowerBound) / (stubExpandTRange.upperBound - stubExpandTRange.lowerBound), 0), 1)
        let stubRemoveTopCornersT = min(max((t - stubRemoveTopCornersTRange.lowerBound) / (stubRemoveTopCornersTRange.upperBound - stubRemoveTopCornersTRange.lowerBound), 0), 1)
        let stubSlopeT = min(max((t - stubSlopeTRange.lowerBound) / (stubSlopeTRange.upperBound - stubSlopeTRange.lowerBound), 0), 1)
        let contentsExpandT = min(max((t - contentsExpandTRange.lowerBound) / (contentsExpandTRange.upperBound - contentsExpandTRange.lowerBound), 0), 1)
        
        // animation stage
        let stage = (stubSlopeT > 0 ? Stage.bloom : Stage.expand)
        
        // stub frame
        let stubTInverseInset = CGSize(width: stubFullInsetSize.width * (1 - stubExpandedT),
                                       height: stubFullInsetSize.height * (1 - stubExpandedT))
        let stubTFrame = CGRect(x: stubFrame.origin.x + stubTInverseInset.width,
                                y: stubFrame.origin.y + stubTInverseInset.width,
                                width: stubFrame.width - stubTInverseInset.width * 2,
                                height: stubFrame.height - stubTInverseInset.height * 2)
        
        // stub interpolated properties
        let stubTNonContentsCornerRadius = stubStartCornerRadius + (stubEndCornerRadius - stubStartCornerRadius) * stubExpandedT //lower corner
        let stubTContentsCornerRadius = stubTNonContentsCornerRadius + stubRemoveTopCornersT * (0 - stubTNonContentsCornerRadius) //upper corner in first animation
        let stubTNonContentsCornerCircleStart: CGPoint
        let stubTNonContentsCornerCircleEnd: CGPoint
        if side == 0 {
            stubTNonContentsCornerCircleStart = CGPoint(x: stubTFrame.minX + stubTNonContentsCornerRadius, y: stubTFrame.minY + stubTNonContentsCornerRadius)
            stubTNonContentsCornerCircleEnd = CGPoint(x: stubTFrame.maxX - stubTNonContentsCornerRadius, y: stubTFrame.minY + stubTNonContentsCornerRadius)
        }
        else {
            stubTNonContentsCornerCircleStart = CGPoint(x: stubTFrame.minX + stubTNonContentsCornerRadius, y: stubTFrame.maxY - stubTNonContentsCornerRadius)
            stubTNonContentsCornerCircleEnd = CGPoint(x: stubTFrame.maxX - stubTNonContentsCornerRadius, y: stubTFrame.maxY - stubTNonContentsCornerRadius)
        }
        
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
                    let baseBezierRadius = maximumSlopeBezierRadius
                    let baseAngle = maximumSlopeAngle * ((2 * CGFloat.pi) / 360.0)
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
            
            // TODO: "slopeL" to "slopeStart"
            
            slopeLCannotCurve = slopeLFarthestPossibleT < minStubSlopeClampedT
            slopeRCannotCurve = slopeRFarthestPossibleT < minStubSlopeClampedT
            let slopeLT = (slopeLCannotCurve ? 0 : stubSlopeT * min(max(slopeLFarthestPossibleT, 0), 1))
            let slopeRT = (slopeRCannotCurve ? 0 : stubSlopeT * min(max(slopeRFarthestPossibleT, 0), 1))
            
            slopeAngleL = slopeLT * (maximumSlopeAngle * ((2 * CGFloat.pi) / 360.0))
            slopeAngleR = slopeRT * (maximumSlopeAngle * ((2 * CGFloat.pi) / 360.0))
            let stubTSlopeContentsBezierRadiusL = maximumSlopeBezierRadius * slopeLT
            let stubTSlopeContentsBezierRadiusR = maximumSlopeBezierRadius * slopeRT
            
            // stub corner/slope key properties
            // no need to add pi/2 b/c measured from right, not from top
            // end = connection to lower circle, start = connection to contents box
            slopeLEnd = circlePoint(c: stubTNonContentsCornerCircleStart, r: stubTNonContentsCornerRadius, a: -slopeAngleL + CGFloat.pi, clockwise: clockwise)
            slopeREnd = circlePoint(c: stubTNonContentsCornerCircleEnd, r: stubTNonContentsCornerRadius, a: slopeAngleR, clockwise: clockwise)
            if side == 0 {
                let slopeLHeight = -slopeLEnd.y + stubTFrame.maxY
                let slopeRHeight = -slopeREnd.y + stubTFrame.maxY
                let slopeLWidth = slopeLHeight * tan(slopeAngleL)
                let slopeRWidth = slopeRHeight * tan(slopeAngleR)
                slopeLStart = CGPoint(x: slopeLEnd.x - slopeLWidth, y: slopeLEnd.y + slopeLHeight)
                slopeRStart = CGPoint(x: slopeREnd.x + slopeRWidth, y: slopeREnd.y + slopeRHeight)
            }
            else {
                let slopeLHeight = slopeLEnd.y - stubTFrame.minY
                let slopeRHeight = slopeREnd.y - stubTFrame.minY
                let slopeLWidth = slopeLHeight * tan(slopeAngleL)
                let slopeRWidth = slopeRHeight * tan(slopeAngleR)
                slopeLStart = CGPoint(x: slopeLEnd.x - slopeLWidth, y: slopeLEnd.y - slopeLHeight)
                slopeRStart = CGPoint(x: slopeREnd.x + slopeRWidth, y: slopeREnd.y - slopeRHeight)
            }
            
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
            // NEXT: side adjustment
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
        let y: CGFloat
        if side == 0 {
            y = stubTFrame.maxY
        }
        else if side == 2 {
            y = stubTFrame.minY - contentsTHeight
        }
        else {
            // TODO: fix other side if/elses
            assert(false, "horizontal layout not yet ready")
            y = 0
            return
        }
        let contentsTFrame = CGRect(x: contentsTXL,
                                    y: y,
                                    width: contentsTXR - contentsTXL,
                                    height: contentsTHeight)
        
        // contents corners
        let contentsTStubStartOverhang = slopeLStartCurveStart.x - contentsTFrame.minX
        let contentsTStubEndOverhang = -slopeRStartCurveStart.x + contentsTFrame.maxX
        let contentsTMaxCornerRadius = min(contentsTFrame.size.height/2, contentsCornerRadius)
        let contentsTStubStartCornerRadius = min(contentsTMaxCornerRadius, contentsTStubStartOverhang)
        let contentsTStubEndCornerRadius = min(contentsTMaxCornerRadius, contentsTStubEndOverhang)
        
        var tempOverflowAngleL: CGFloat = 0
        var tempOverflowAngleR: CGFloat = 0
        
        cornerConnectionApproximation: do {
            // adjusted to always be UR of stub corners
            let contentsStubCornerStart: CGPoint
            let contentsStubCornerEnd: CGPoint
            
            if side == 0 {
                contentsStubCornerStart = CGPoint(
                    x: stubTNonContentsCornerCircleStart.x + (stubTNonContentsCornerCircleStart.x - (contentsTFrame.minX + contentsTStubStartCornerRadius)),
                    y: stubTNonContentsCornerCircleStart.y - (-stubTNonContentsCornerCircleStart.y + (contentsTFrame.minY + contentsTStubStartCornerRadius)))
                contentsStubCornerEnd = CGPoint(
                    x: contentsTFrame.maxX - contentsTStubEndCornerRadius,
                    y: stubTNonContentsCornerCircleEnd.y - (-stubTNonContentsCornerCircleEnd.y + (contentsTFrame.minY + contentsTStubEndCornerRadius)))
            }
            else {
                contentsStubCornerStart = CGPoint(
                    x: stubTNonContentsCornerCircleStart.x + (stubTNonContentsCornerCircleStart.x - (contentsTFrame.minX + contentsTStubStartCornerRadius)),
                    y: contentsTFrame.maxY - contentsTStubStartCornerRadius)
                contentsStubCornerEnd = CGPoint(
                    x: contentsTFrame.maxX - contentsTStubEndCornerRadius,
                    y: contentsTFrame.maxY - contentsTStubEndCornerRadius)
            }
            
            let contentsCornerRadiusL = contentsTStubStartCornerRadius
            let contentsCornerRadiusR = contentsTStubEndCornerRadius
            let stubCornerRadius = stubTNonContentsCornerRadius
            
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
            
            let lAngleU = newton(function: ffx(stubTNonContentsCornerCircleStart, contentsStubCornerStart, stubCornerRadius, contentsCornerRadiusL),
                                 derivative: ffdx(stubTNonContentsCornerCircleStart, contentsStubCornerStart, stubCornerRadius, contentsCornerRadiusL),
                                 transform: cleanup,
                                 x0: CGFloat.pi/4)
            let rAngleU = newton(function: ffx(stubTNonContentsCornerCircleEnd, contentsStubCornerEnd, stubCornerRadius, contentsCornerRadiusR),
                                 derivative: ffdx(stubTNonContentsCornerCircleEnd, contentsStubCornerEnd, stubCornerRadius, contentsCornerRadiusR),
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
            
            // QQQ: changing shit around
            do {
                if slopeLCannotCurve {
                    slopeAngleL = tempOverflowAngleL
                    slopeLStart = circlePoint(c: contentsStubCornerStart, r: contentsTStubStartCornerRadius, a: -slopeAngleL + CGFloat.pi, clockwise: clockwise)
                    slopeLEnd = circlePoint(c: stubTNonContentsCornerCircleStart, r: stubTNonContentsCornerRadius, a: -slopeAngleL + CGFloat.pi, clockwise: clockwise)
                }
                if slopeRCannotCurve {
                    slopeAngleR = tempOverflowAngleR
                    slopeRStart = circlePoint(c: contentsStubCornerEnd, r: contentsTStubEndCornerRadius, a: slopeAngleR, clockwise: clockwise)
                    slopeREnd = circlePoint(c: stubTNonContentsCornerCircleEnd, r: stubTNonContentsCornerRadius, a: slopeAngleR, clockwise: clockwise)
                }
            }
        }
        
        // final gathering point of relevant vertices, so they don't have to be calculated on the fly inside the draw sections
        // start to end is always +x or +y, so clock direction is flipped when stub changes sides
        let contentsPoints: (
            stubStart0: CGPoint, stubStart: CGPoint, stubStart1: CGPoint,
            nonStubStart0: CGPoint, nonStubStart: CGPoint, nonStubStart1: CGPoint,
            nonStubEnd0: CGPoint, nonStubEnd: CGPoint, nonStubEnd1: CGPoint,
            stubEnd0: CGPoint, stubEnd: CGPoint, stubEnd1: CGPoint)
        let contentsCorners: (
            stubStart: CGPoint,
            nonStubStart: CGPoint,
            nonStubEnd: CGPoint,
            stubEnd: CGPoint)
        let stubPoints: (
            contentsEnd0: CGPoint, contentsEnd: CGPoint, contentsEnd1: CGPoint,
            nonContentsEnd0: CGPoint, nonContentsEnd: CGPoint, nonContentsEnd1: CGPoint,
            nonContentsStart0: CGPoint, nonContentsStart: CGPoint, nonContentsStart1: CGPoint,
            contentsStart0: CGPoint, contentsStart: CGPoint, contentsStart1: CGPoint)
        let stubCorners: (
            contentsEnd: CGPoint,
            nonContentsEnd: CGPoint,
            nonContentsStart: CGPoint,
            contentsStart: CGPoint)
        
        if side == 0 {
            contentsPoints = (CGPoint(x: contentsTFrame.minX + contentsTStubStartCornerRadius, y: contentsTFrame.minY),
                              CGPoint(x: contentsTFrame.minX, y: contentsTFrame.minY),
                              CGPoint(x: contentsTFrame.minX, y: contentsTFrame.minY + contentsTStubStartCornerRadius),
                              
                              CGPoint(x: contentsTFrame.minX, y: contentsTFrame.maxY - contentsTMaxCornerRadius),
                              CGPoint(x: contentsTFrame.minX, y: contentsTFrame.maxY),
                              CGPoint(x: contentsTFrame.minX + contentsTMaxCornerRadius, y: contentsTFrame.maxY),
                              
                              CGPoint(x: contentsTFrame.maxX - contentsTMaxCornerRadius, y: contentsTFrame.maxY),
                              CGPoint(x: contentsTFrame.maxX, y: contentsTFrame.maxY),
                              CGPoint(x: contentsTFrame.maxX, y: contentsTFrame.maxY - contentsTMaxCornerRadius),
                              
                              CGPoint(x: contentsTFrame.maxX, y: contentsTFrame.minY + contentsTStubEndCornerRadius),
                              CGPoint(x: contentsTFrame.maxX, y: contentsTFrame.minY),
                              CGPoint(x: contentsTFrame.maxX - contentsTStubEndCornerRadius, y: contentsTFrame.minY))
            
            contentsCorners = (CGPoint(x: contentsTFrame.minX + contentsTStubStartCornerRadius, y: contentsTFrame.minY + contentsTStubStartCornerRadius),
                               CGPoint(x: contentsTFrame.minX + contentsTMaxCornerRadius, y: contentsTFrame.maxY - contentsTMaxCornerRadius),
                               CGPoint(x: contentsTFrame.maxX - contentsTMaxCornerRadius, y: contentsTFrame.maxY - contentsTMaxCornerRadius),
                               CGPoint(x: contentsTFrame.maxX - contentsTStubEndCornerRadius, y: contentsTFrame.minY + contentsTStubEndCornerRadius))
            
            stubPoints = (CGPoint(x: stubTFrame.maxX - stubTContentsCornerRadius, y: stubTFrame.maxY),
                          CGPoint(x: stubTFrame.maxX, y: stubTFrame.maxY),
                          CGPoint(x: stubTFrame.maxX, y: stubTFrame.maxY - stubTContentsCornerRadius),
                
                          CGPoint(x: stubTFrame.maxX, y: stubTFrame.minY + stubTNonContentsCornerRadius),
                          CGPoint(x: stubTFrame.maxX, y: stubTFrame.minY),
                          CGPoint(x: stubTFrame.maxX - stubTNonContentsCornerRadius, y: stubTFrame.minY),
                          
                          CGPoint(x: stubTFrame.minX + stubTNonContentsCornerRadius, y: stubTFrame.minY),
                          CGPoint(x: stubTFrame.minX, y: stubTFrame.minY),
                          CGPoint(x: stubTFrame.minX, y: stubTFrame.minY + stubTNonContentsCornerRadius),
                          
                          CGPoint(x: stubTFrame.minX, y: stubTFrame.maxY - stubTContentsCornerRadius),
                          CGPoint(x: stubTFrame.minX, y: stubTFrame.maxY),
                          CGPoint(x: stubTFrame.minX + stubTContentsCornerRadius, y: stubTFrame.maxY))
            
            stubCorners = (CGPoint(x: stubTFrame.maxX - stubTContentsCornerRadius, y: stubTFrame.maxY - stubTContentsCornerRadius),
                           CGPoint(x: stubTFrame.maxX - stubTNonContentsCornerRadius, y: stubTFrame.minY + stubTNonContentsCornerRadius),
                           CGPoint(x: stubTFrame.minX + stubTNonContentsCornerRadius, y: stubTFrame.minY + stubTNonContentsCornerRadius),
                           CGPoint(x: stubTFrame.minX + stubTContentsCornerRadius, y: stubTFrame.maxY - stubTContentsCornerRadius))
        }
        else {
            contentsPoints = (CGPoint(x: contentsTFrame.minX + contentsTStubStartCornerRadius, y: contentsTFrame.maxY),
                              CGPoint(x: contentsTFrame.minX, y: contentsTFrame.maxY),
                              CGPoint(x: contentsTFrame.minX, y: contentsTFrame.maxY - contentsTStubStartCornerRadius),
                
                              CGPoint(x: contentsTFrame.minX, y: contentsTFrame.minY + contentsTMaxCornerRadius),
                              CGPoint(x: contentsTFrame.minX, y: contentsTFrame.minY),
                              CGPoint(x: contentsTFrame.minX + contentsTMaxCornerRadius, y: contentsTFrame.minY),
                              
                              CGPoint(x: contentsTFrame.maxX - contentsTMaxCornerRadius, y: contentsTFrame.minY),
                              CGPoint(x: contentsTFrame.maxX, y: contentsTFrame.minY),
                              CGPoint(x: contentsTFrame.maxX, y: contentsTFrame.minY + contentsTMaxCornerRadius),
                              
                              CGPoint(x: contentsTFrame.maxX, y: contentsTFrame.maxY - contentsTStubEndCornerRadius),
                              CGPoint(x: contentsTFrame.maxX, y: contentsTFrame.maxY),
                              CGPoint(x: contentsTFrame.maxX - contentsTStubEndCornerRadius, y: contentsTFrame.maxY))
            
            contentsCorners = (CGPoint(x: contentsTFrame.minX + contentsTStubStartCornerRadius, y: contentsTFrame.maxY - contentsTStubStartCornerRadius),
                               CGPoint(x: contentsTFrame.minX + contentsTMaxCornerRadius, y: contentsTFrame.minY + contentsTMaxCornerRadius),
                               CGPoint(x: contentsTFrame.maxX - contentsTMaxCornerRadius, y: contentsTFrame.minY + contentsTMaxCornerRadius),
                               CGPoint(x: contentsTFrame.maxX - contentsTStubEndCornerRadius, y: contentsTFrame.maxY - contentsTStubEndCornerRadius))
            
            stubPoints = (CGPoint(x: stubTFrame.maxX - stubTContentsCornerRadius, y: stubTFrame.minY),
                          CGPoint(x: stubTFrame.maxX, y: stubTFrame.minY),
                          CGPoint(x: stubTFrame.maxX, y: stubTFrame.minY + stubTContentsCornerRadius),
                          
                          CGPoint(x: stubTFrame.maxX, y: stubTFrame.maxY - stubTNonContentsCornerRadius),
                          CGPoint(x: stubTFrame.maxX, y: stubTFrame.maxY),
                          CGPoint(x: stubTFrame.maxX - stubTNonContentsCornerRadius, y: stubTFrame.maxY),
                          
                          CGPoint(x: stubTFrame.minX + stubTNonContentsCornerRadius, y: stubTFrame.maxY),
                          CGPoint(x: stubTFrame.minX, y: stubTFrame.maxY),
                          CGPoint(x: stubTFrame.minX, y: stubTFrame.maxY - stubTNonContentsCornerRadius),
                          
                          CGPoint(x: stubTFrame.minX, y: stubTFrame.minY + stubTContentsCornerRadius),
                          CGPoint(x: stubTFrame.minX, y: stubTFrame.minY),
                          CGPoint(x: stubTFrame.minX + stubTContentsCornerRadius, y: stubTFrame.minY))
            
            stubCorners = (CGPoint(x: stubTFrame.maxX - stubTContentsCornerRadius, y: stubTFrame.minY + stubTContentsCornerRadius),
                           CGPoint(x: stubTFrame.maxX - stubTNonContentsCornerRadius, y: stubTFrame.maxY - stubTNonContentsCornerRadius),
                           CGPoint(x: stubTFrame.minX + stubTNonContentsCornerRadius, y: stubTFrame.maxY - stubTNonContentsCornerRadius),
                           CGPoint(x: stubTFrame.minX + stubTContentsCornerRadius, y: stubTFrame.minY + stubTContentsCornerRadius))
        }
        
        let shape = UIBezierPath()
        
        let angleMultiplier: CGFloat = (clockwise ? 1 : -1)
        
        if stage == .expand {
            drawStub: do {
                shape.move(to: stubPoints.contentsEnd0)
                shape.addArc(withCenter: stubCorners.contentsEnd,
                             radius: stubTContentsCornerRadius,
                             startAngle: angleMultiplier * -CGFloat.pi/2,
                             endAngle: angleMultiplier * 0,
                             clockwise: clockwise)
                shape.addLine(to: stubPoints.nonContentsEnd0)
                shape.addArc(withCenter: stubCorners.nonContentsEnd,
                             radius: stubTNonContentsCornerRadius,
                             startAngle: angleMultiplier * 0,
                             endAngle: angleMultiplier * CGFloat.pi/2,
                             clockwise: clockwise)
                shape.addLine(to: stubPoints.nonContentsStart0)
                shape.addArc(withCenter: stubCorners.nonContentsStart,
                             radius: stubTNonContentsCornerRadius,
                             startAngle: angleMultiplier * CGFloat.pi/2,
                             endAngle: angleMultiplier * CGFloat.pi,
                             clockwise: clockwise)
                shape.addLine(to: stubPoints.contentsStart0)
                shape.addArc(withCenter: stubCorners.contentsStart,
                             radius: stubTContentsCornerRadius,
                             startAngle: angleMultiplier * CGFloat.pi,
                             endAngle: angleMultiplier * CGFloat.pi * 1.5,
                             clockwise: clockwise)
            }
        }
        else {
            drawShape: do {
                if slopeLCannotCurve {
                    //shape.move(to: slopeLStart)
                    shape.move(to: contentsPoints.stubStart1)
                }
                else {
                    shape.move(to: slopeLStartCurveStart)
                    
                    shape.addLine(to: contentsPoints.stubStart0)
                    shape.addArc(withCenter: contentsCorners.stubStart,
                                 radius: contentsTStubStartCornerRadius,
                                 startAngle: angleMultiplier * CGFloat.pi/2,
                                 endAngle: angleMultiplier * CGFloat.pi,
                                 clockwise: clockwise)
                }
                
                shape.addLine(to: contentsPoints.nonStubStart0)
                shape.addArc(withCenter: contentsCorners.nonStubStart,
                             radius: contentsTMaxCornerRadius,
                             startAngle: angleMultiplier * CGFloat.pi,
                             endAngle: angleMultiplier * CGFloat.pi * 1.5,
                             clockwise: clockwise)
                shape.addLine(to: contentsPoints.nonStubEnd0)
                shape.addArc(withCenter: contentsCorners.nonStubEnd,
                             radius: contentsTMaxCornerRadius,
                             startAngle: angleMultiplier * -CGFloat.pi/2,
                             endAngle: angleMultiplier * 0,
                             clockwise: clockwise)
                
                if slopeRCannotCurve {
                    shape.addLine(to: contentsPoints.stubEnd0)
                    //shape.addLine(to: slopeRStart)
                }
                else {
                    shape.addLine(to: contentsPoints.stubEnd0)
                    shape.addArc(withCenter: contentsCorners.stubEnd,
                                 radius: contentsTStubEndCornerRadius,
                                 startAngle: angleMultiplier * 0,
                                 endAngle: angleMultiplier * CGFloat.pi/2,
                                 clockwise: clockwise)
                }
            }
            
            drawStub: do {
                if slopeRCannotCurve {
                    shape.addArc(withCenter: contentsCorners.stubEnd,
                                 radius: contentsTStubEndCornerRadius,
                                 startAngle: angleMultiplier * 0,
                                 endAngle: angleMultiplier * slopeAngleR,
                                 clockwise: clockwise)
                }
                else {
                    shape.addLine(to: slopeRStartCurveStart)
                    
                    // contents curve R
                    shape.addCurve(to: slopeRStartCurveEnd, controlPoint1: slopeRStart, controlPoint2: slopeRStart)
                }
                
                shape.addLine(to: slopeREnd)
                
                // corner curve R
                shape.addArc(withCenter: stubCorners.nonContentsEnd,
                             radius: stubTNonContentsCornerRadius,
                             startAngle: angleMultiplier * slopeAngleR,
                             endAngle: angleMultiplier * CGFloat.pi/2,
                             clockwise: clockwise)
                
                shape.addLine(to: stubPoints.nonContentsStart0)
                
                // corner curve L
                shape.addArc(withCenter: stubCorners.nonContentsStart,
                             radius: stubTNonContentsCornerRadius,
                             startAngle: angleMultiplier * CGFloat.pi/2,
                             endAngle: angleMultiplier * (CGFloat.pi/2 + (CGFloat.pi/2 - slopeAngleL)),
                             clockwise: clockwise)
                
                if slopeLCannotCurve {
                    shape.addLine(to: slopeLEnd)
                    shape.addArc(withCenter: contentsCorners.stubStart,
                                 radius: contentsTStubStartCornerRadius,
                                 startAngle: angleMultiplier * (CGFloat.pi - slopeAngleR),
                                 endAngle: angleMultiplier * CGFloat.pi,
                                 clockwise: clockwise)
                }
                else {
                    shape.addLine(to: slopeLStartCurveEnd)
                    
                    // contents curve L
                    shape.addCurve(to: slopeLStartCurveStart, controlPoint1: slopeLStart, controlPoint2: slopeLStart)
                }
            }
        }
        
        shape.close()
        
        if let debugLayer = self.debugLayer {
            if let sublayers = debugLayer.layer.sublayers {
                for sublayer in sublayers {
                    sublayer.removeFromSuperlayer()
                }
            }
            
            // bezier control points
            for (i, point) in [slopeLStartCurveStart, slopeLStart, slopeLStartCurveEnd,
                               slopeRStartCurveStart, slopeRStart, slopeRStartCurveEnd].enumerated()
            {
                if stage != .bloom {
                    continue
                }
                if i < 3 && slopeLCannotCurve {
                    continue
                }
                if i >= 3 && slopeRCannotCurve {
                    continue
                }
                
                let radius: CGFloat = 2
                let color = UIColor.white
                
                let shape = CAShapeLayer()
                let bezier = UIBezierPath(roundedRect: CGRect(x: point.x-radius, y: point.y-radius, width: radius*2, height: radius*2), cornerRadius: radius)
                shape.path = bezier.cgPath
                shape.fillColor = color.cgColor
                
                debugLayer.layer.addSublayer(shape)
            }
            
            // corners
            for (i, point) in [contentsCorners.stubStart, contentsCorners.nonStubStart, contentsCorners.nonStubEnd, contentsCorners.stubEnd].enumerated() {
                let radius: CGFloat
                if i == 0 {
                    radius = contentsTStubStartCornerRadius
                }
                else if i == 3 {
                    radius = contentsTStubEndCornerRadius
                }
                else {
                    radius = contentsTMaxCornerRadius
                }
                
                let color = UIColor.white
                let lineWidth: CGFloat = 1
                
                let shape = CAShapeLayer()
                let bezier = UIBezierPath(roundedRect: CGRect(x: point.x-radius, y: point.y-radius, width: radius*2, height: radius*2), cornerRadius: radius)
                shape.path = bezier.cgPath
                shape.strokeColor = color.cgColor
                shape.fillColor = nil
                shape.lineWidth = lineWidth
                
                debugLayer.layer.addSublayer(shape)
            }
            
        }
        
        self.shape.shape = shape
        
        // KLUDGE: this belongs elsewhere, but we don't have access to contentsExpandT outside of this method
        fancyEffects: do {
            let t = contentsExpandT
            let offset: CGFloat = (side == 0 ? -60 : 60)
            let translate = CGAffineTransform(translationX: 0, y: offset + t * -offset)
            let scale = CGAffineTransform(scaleX: 1, y: 1)
            let transform = translate.concatenating(scale)
            self.title.transform = transform
            self.selectionViewContainer.transform = transform
            self.contentsContainer.alpha = contentsExpandT
        }
    }
}

// layout: these should not access view data and instead operate purely mathematically (though we make an exception for the title field)
extension SelectionPopup {
    // expanded stub size
    func calculateStubSize() -> CGSize {
        let vertical = (anchorPosition.side == 0 || anchorPosition.side == 2)
        
        if vertical {
            return CGSize(width: anchorExpandedSize.width, height: anchorExpandedSize.height)
        }
        else {
            return CGSize(width: anchorExpandedSize.height, height: anchorExpandedSize.width)
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
        let titleTransform = self.title.transform
        self.title.transform = CGAffineTransform.identity
        
        var boundingBox: CGSize
        let stubFrame: CGRect
        var contentsContainerFrame = CGRect.zero
        var contentsInnerSize = CGSize.zero
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
            
            contentsInnerSize = CGSize(
                width: margin + selectionContainerFrame.size.width + margin,
                height: margin + titleFrame.size.height + margin + selectionContainerFrame.size.height + margin)
            
            // container can't be smaller than maximally expanded stub or title
            if stubVertical {
                contentsInnerSize.width = max(contentsInnerSize.width, stubSize.width * minimumContentsMultiplierAlongAnchorAxis)
                contentsInnerSize.width = max(contentsInnerSize.width, margin + titleFrame.size.width + margin)
            }
            else {
                contentsInnerSize.height = max(contentsInnerSize.height, stubSize.height * minimumContentsMultiplierAlongAnchorAxis)
            }
            
            contentsContainerFrame.size = CGSize(
                width: self.contentInset.left + contentsInnerSize.width + self.contentInset.right,
                height: self.contentInset.top + contentsInnerSize.height + self.contentInset.bottom)
            
            titleFrame.origin = CGPoint(x: self.contentInset.left + (contentsInnerSize.width/2 - titleFrame.size.width/2),
                                        y: self.contentInset.top + margin)
            
            selectionContainerFrame.origin = CGPoint(x: self.contentInset.left + (contentsInnerSize.width/2 - selectionContainerFrame.size.width/2),
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
