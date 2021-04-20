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
    var framesInfo = [String: FrameInfo]()

    func viewportPos(value: CGFloat, origin: String, prop: String) -> CGFloat {
        var framePos: CGFloat = 0
        if framesInfo.count > 0 {
            var currentOrigin = origin
            repeat {
                let foundFrameInfo = framesInfo[currentOrigin]
                if foundFrameInfo != nil {
                    let frameInfo = foundFrameInfo!
                    framePos += prop == "x" ? frameInfo.x : frameInfo.y
                    currentOrigin = frameInfo.origin
                    break
                } else {
                    Logger.shared.logError("""
                                           Could not find frameInfo for origin \(currentOrigin)
                                           in \(framesInfo.map { $0.value.origin })
                                           """, category: .web)
                    break
                }
            } while framesInfo[currentOrigin]?.origin != currentOrigin
        }
        let pos = framePos + value
        return pos
    }

    func viewportX(frameX: CGFloat, origin: String) -> CGFloat {
        viewportPos(value: frameX, origin: origin, prop: "x")
    }

    func viewportY(frameY: CGFloat, origin: String) -> CGFloat {
        viewportPos(value: frameY, origin: origin, prop: "y")
    }

    func viewportWidth(width: CGFloat) -> CGFloat {
        width
    }

    func viewportHeight(height: CGFloat) -> CGFloat {
        height
    }

    /**
     Resolve some area coords sent by JS to a NSRect with coords on the WebView frame.
     - Parameters:
       - area: The area coords as sent by JS.
       - origin: URL where the text comes from. This helps resolving the position of a selection in iframes.
     - Returns:
     */
    func viewportArea(area: NSRect, origin: String) -> NSRect {
        let minX = viewportX(frameX: area.minX, origin: origin)
        let minY = viewportY(frameY: area.minY, origin: origin)
        let width = viewportWidth(width: area.width)
        let height = viewportHeight(height: area.height)
        return NSRect(x: minX, y: minY, width: width, height: height)
    }

    func registerOrigin(origin: String) {
        var originFrame = framesInfo[origin]
        if originFrame == nil {
            originFrame = FrameInfo(origin: origin, x: 0, y: 0, width: -1, height: -1)
            framesInfo[origin] = originFrame
        }
        Logger.shared.logInfo("registerOrigin: framesInfo=\(framesInfo)", category: .pointAndShoot)
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
