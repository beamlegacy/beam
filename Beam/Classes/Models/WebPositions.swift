import BeamCore

/**
 Computes blocks positions on the native web view
 from the frame-relative positions provided by JavaScript in a web frame.
 */

class WebPositions {
    var scale: CGFloat = 1

    /**
     * Frame info by frame URL
     */
    var framesInfo = [HREF: FrameInfo]()

    typealias HREF = String
    typealias ParentHREF = String

    enum FramePosition {
        case x
        case y
        case scrollX
        case scrollY
    }

    struct FrameInfo {
        var href: HREF
        var parentHref: ParentHREF
        var x: CGFloat = 0
        var y: CGFloat = 0
        var scrollX: CGFloat = 0
        var scrollY: CGFloat = 0
        var width: CGFloat = -1
        var height: CGFloat = -1
    }

    /// Utility to check if provided frame is a child frame
    /// - Parameter frame: frame to set
    /// - Returns: true if frame isn't the root frame
    fileprivate func isChild(_ frame: WebPositions.FrameInfo) -> Bool {
        return frame.href != frame.parentHref
    }

    /// Recursively calculate the position of a frame's prop
    /// - Parameters:
    ///   - href: url of frame
    ///   - prop: positional property to calculate
    ///   - allPositions: Used as aggregator Array for recursive calculation
    /// - Returns: Array of values, starting with the frame's own value.
    private func calculateViewportPosition(href: HREF, prop: FramePosition, allPositions: [CGFloat] = []) -> [CGFloat] {
        // by default allPositions starts as empty array []
        // reassign allPositions to mutable value
        var positions: [CGFloat] = allPositions
        // get full frameInfo from framesInfo dict
        if framesInfo[href] == nil {
            return positions
        }
        let frame = framesInfo[href]!
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
        // If we aren't on the root frame
        if isChild(frame) {
            // run this function recursively
            return calculateViewportPosition(href: frame.parentHref, prop: prop, allPositions: positions)
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
        if framesInfo.count > 0 {
            return calculateViewportPosition(href: href, prop: prop)
        }
        return [0.0]
    }

    /// Sets frameInfo to stored dict. Will only set frameInfo when the provided frame is a child frame, or isn't registered yet.
    /// - Parameter frame: a full FrameInfo object
    func setFrameInfo(frame: FrameInfo) {
        if isChild(frame) {
            framesInfo[frame.href] = frame
        }

        if framesInfo[frame.href] == nil {
            framesInfo[frame.href] = frame
        }
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

    /**
     - Parameter jsArea: a dictionary with x, y, width and height
     - Returns:
     */
    func jsToRect(jsArea: AnyObject) -> NSRect {
        guard let frameX = jsArea["x"] as? CGFloat,
              let frameY = jsArea["y"] as? CGFloat,
              let width = jsArea["width"] as? CGFloat,
              let height = jsArea["height"] as? CGFloat else {
            return .zero
        }
        return NSRect(x: frameX, y: frameY, width: width, height: height)
    }

    /**
     - Parameter jsPoint: a dictionary with x, y
     - Returns:
     */
    func jsToPoint(jsPoint: AnyObject) -> NSPoint {
        guard let frameX = jsPoint["x"] as? CGFloat,
              let frameY = jsPoint["y"] as? CGFloat else {
            return .zero
        }
        return NSPoint(x: frameX, y: frameY)
    }
}
