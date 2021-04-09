import BeamCore

class WebPositions {
    var scale: CGFloat = 1

    /**
     * Frame info by frame URL
     */
    var framesInfo = [String: FrameInfo]()

    func absolutePosition(v: CGFloat, origin: String, prop: String) -> CGFloat {
        var framePos: CGFloat = 0
        if framesInfo.count > 0 {
            var currentOrigin = origin
            repeat {
                let foundFrameInfo = framesInfo[currentOrigin]
                if foundFrameInfo != nil {
                    let frameInfo = foundFrameInfo!
                    framePos += prop == "x" ? frameInfo.x : frameInfo.y
                    currentOrigin = frameInfo.origin
                } else {
                    Logger.shared.logError("""
                                           Could not find frameInfo for origin \(currentOrigin)
                                           in \(framesInfo.map { $0.value.origin })
                                           """, category: .web)
                    break
                }
            } while framesInfo[currentOrigin]?.origin != currentOrigin
        }
        let pos = framePos + v
        return pos * scale
    }

    func nativeX(x: CGFloat, origin: String) -> CGFloat {
        absolutePosition(v: x, origin: origin, prop: "x")
    }

    func nativeY(y: CGFloat, origin: String) -> CGFloat {
        absolutePosition(v: y, origin: origin, prop: "y")
    }

    func nativeWidth(width: CGFloat) -> CGFloat {
        width * scale
    }

    func nativeHeight(height: CGFloat) -> CGFloat {
        height * scale
    }

    /**
     Resolve some area coords sent by JS to a NSRect with coords on the WebView frame.
     - Parameters:
       - area: The area coords as sent by JS.
       - origin: URL where the text comes from. This helps resolving the position of a selection in iframes.
     - Returns:
     */
    func nativeArea(area: NSRect, origin: String) -> NSRect {
        let minX = nativeX(x: area.minX, origin: origin)
        let minY = nativeY(y: area.minY, origin: origin)
        let width = nativeWidth(width: area.width)
        let height = nativeHeight(height: area.height)
        return NSRect(x: minX, y: minY, width: width, height: height)
    }

    func registerOrigin(origin: String) {
        var originFrame = framesInfo[origin]
        if originFrame == nil {
            originFrame = FrameInfo(origin: origin, x: 0, y: 0, width: -1, height: -1)
            framesInfo[origin] = originFrame
        }
    }

    /**
  - Parameter jsArea: a dictionary with x, y, width and height
  - Returns:
  */
    func jsToRect(jsArea: AnyObject) -> NSRect {
        guard let x = jsArea["x"] as? CGFloat,
              let y = jsArea["y"] as? CGFloat,
              let width = jsArea["width"] as? CGFloat,
              let height = jsArea["height"] as? CGFloat else {
            return .zero
        }
        return NSRect(x: x, y: y, width: width, height: height)
    }

    /**
  - Parameter jsPoint: a dictionary with x, y
  - Returns:
  */
    func jsToPoint(jsPoint: AnyObject) -> NSPoint {
        guard let x = jsPoint["x"] as? CGFloat,
              let y = jsPoint["y"] as? CGFloat else {
            return .zero
        }
        return NSPoint(x: x, y: y)
    }
}
