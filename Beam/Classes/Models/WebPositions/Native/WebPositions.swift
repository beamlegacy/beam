import BeamCore
import Combine

protocol WebPositionsDelegate: AnyObject {
    func webPositionsDidUpdateScroll(with frame: WebFrames.FrameInfo)
    func webPositionsDidUpdateSize(with frame: WebFrames.FrameInfo)
}
/**
 Computes blocks positions on the native web view
 from the frame-relative positions provided by JavaScript in a web frame.
 */
class WebPositions: ObservableObject {
    /**
     * Frame info by frame URL
     */
    internal var framesInfo = [HREF: WebFrames.FrameInfo]() // can't be made private for unit tests

    typealias HREF = String
    typealias ParentHREF = String

    enum FramePosition {
        case x
        case y
        case scrollX
        case scrollY
    }

    weak var delegate: WebPositionsDelegate?

    private var cancellables = Set<AnyCancellable>()

    init(webFrames: WebFrames) {
        webFrames.$framesInfo.sink { [weak self] framesInfo in
            self?.framesInfo = framesInfo
        }
        .store(in: &cancellables)
    }

    private init() {}

    /// Recursively calculate the position of a frame's prop
    /// - Parameters:
    ///   - href: url of frame
    ///   - prop: positional property to calculate
    ///   - allPositions: Used as aggregator Array for recursive calculation
    ///   - depth: Current recursion depth, defaults to 0
    /// - Returns: Array of values, starting with the frame's own value.
    private func calculateViewportPosition(href: HREF, prop: FramePosition, allPositions: [CGFloat] = [], depth: Int = 0) -> [CGFloat] {
        // Limit recursion to a depth of 10
        let DEPTH_LIMIT = 10
        // by default allPositions starts as empty array []
        // reassign allPositions to mutable value
        var positions: [CGFloat] = allPositions
        // get full frameInfo from framesInfo dict
        guard let frame = framesInfo[href] else {
            if positions.count > 0 {
                return positions
            } else {
                return [0.0]
            }
        }
        switch prop {
        case .x:
            positions.append(frame.x)
        case .y:
            positions.append(frame.y)
        case .scrollX:
            positions.append(frame.scrollX)
        case .scrollY:
            positions.append(frame.scrollY)
        }
        // If we aren't on the root frame, and we are below the depth recursion limit
        if frame.hasParentFrame, depth < DEPTH_LIMIT {
            // run this function recursively
            return calculateViewportPosition(href: frame.parentHref, prop: prop, allPositions: positions, depth: depth + 1)
        }
        // return full position array
        return positions
    }

    /// Calculate value of property taking into account parent frame positions
    /// - Parameters:
    ///   - href: url of frame
    ///   - prop: position property to calculate
    /// - Returns: position based on parent frame positions
    func viewportPosition(_ href: HREF, prop: FramePosition) -> [CGFloat] {
        guard framesInfo.count > 0 else {
            return [0.0]
        }

        return calculateViewportPosition(href: href, prop: prop)
    }

    /// Calculate frame position relative to main frame
    /// - Parameters:
    ///   - href: url of frame
    /// - Returns: absolute position
    func viewportPosition(href: HREF) -> CGPoint {
        let frameOffsetX = viewportPosition(href, prop: .x).reduce(0, +)
        let frameOffsetY = viewportPosition(href, prop: .y).reduce(0, +)
        let frameScrollX = viewportPosition(href, prop: .scrollX).reduce(0, +)
        let frameScrollY = viewportPosition(href, prop: .scrollY).reduce(0, +)
        return CGPoint(x: frameOffsetX - frameScrollX, y: frameOffsetY - frameScrollY)
    }

    /// Calculate frame position relative to main frame, ignoring scroll position on target frame
    /// - Parameters:
    ///   - href: url of frame
    /// - Returns: absolute position
    func viewportOffset(href: HREF) -> CGPoint {
        let frameOffsetX = viewportPosition(href, prop: .x).reduce(0, +)
        let frameOffsetY = viewportPosition(href, prop: .y).reduce(0, +)
        let frameScrollX = viewportPosition(href, prop: .scrollX).dropFirst().reduce(0, +)
        let frameScrollY = viewportPosition(href, prop: .scrollY).dropFirst().reduce(0, +)
        return CGPoint(x: frameOffsetX - frameScrollX, y: frameOffsetY - frameScrollY)
    }

    func viewportOffsetForLocation(_ location: CGPoint) -> CGPoint { // FIXME: use scale
        let possibleOffsets = framesInfo.keys
            .map(viewportOffset)
            .filter { offset in
                location.x >= offset.x && location.y >= offset.y
            }
        guard let offset = possibleOffsets.max(by: { $0.x + $0.y < $1.x + $1.y }) else { return .zero }
        return offset
    }

    /// Sets scrollX and scrollY keys on an already registered frame
    /// - Parameters:
    ///   - href: url of frame to update
    ///   - scrollX
    ///   - scrollY
    func setFrameInfoScroll(href: HREF, scrollX: CGFloat, scrollY: CGFloat) {
        guard var frame = framesInfo[href] else { return }
        frame.scrollX = scrollX
        frame.scrollY = scrollY
        framesInfo[href] = frame
        delegate?.webPositionsDidUpdateScroll(with: frame)
    }

    /// Sets size on an already registered frame
    /// - Parameters:
    ///   - href: url of frame to update
    ///   - width
    ///   - height
    func setFrameInfoResize(href: HREF, width: CGFloat, height: CGFloat) {
        guard var frame = framesInfo[href] else { return }
        frame.width = width
        frame.height = height
        framesInfo[href] = frame
        delegate?.webPositionsDidUpdateSize(with: frame)
    }

    /// Utility to remove items from framesInfo
    /// - Parameter from: When provided, only this key will be removed
    func removeFrameInfo(from: HREF? = nil) {
        if let href = from {
            framesInfo.removeValue(forKey: href)
            return
        }

        framesInfo.removeAll()
    }
}
