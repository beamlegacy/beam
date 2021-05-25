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

    func viewportPos(value: CGFloat, href: String, prop: String) -> CGFloat {
        var framePos: CGFloat = 0
        if framesInfo.count > 0 {
            var currentHref = href
            repeat {
                let foundFrameInfo = framesInfo[currentHref]
                if foundFrameInfo != nil {
                    let frameInfo = foundFrameInfo!
                    framePos += prop == "x" ? frameInfo.x : frameInfo.y
                    currentHref = frameInfo.href
                    break
                } else {
                    Logger.shared.logError("""
                                           Could not find frameInfo for href currentHref)
                                           in \(framesInfo.map { $0.value.href })
                                           """, category: .web)
                    break
                }
            } while framesInfo[currentHref]?.href != currentHref
        }
        let pos = framePos + value
        return pos
    }

    func viewportX(frameX: CGFloat, href: String) -> CGFloat {
        viewportPos(value: frameX, href: href, prop: "x")
    }

    func viewportY(frameY: CGFloat, href: String) -> CGFloat {
        viewportPos(value: frameY, href: href, prop: "y")
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
       - href: URL where the text comes from. This helps resolving the position of a selection in iframes.
     - Returns:
     */
    func viewportArea(area: NSRect, href: String) -> NSRect {
        let minX = viewportX(frameX: area.minX, href: href)
        let minY = viewportY(frameY: area.minY, href: href)
        let width = viewportWidth(width: area.width)
        let height = viewportHeight(height: area.height)
        return NSRect(x: minX, y: minY, width: width, height: height)
    }

    func registerHref(href: String) {
        var hrefFrame = framesInfo[href]
        if hrefFrame == nil {
            hrefFrame = FrameInfo(href: href, x: 0, y: 0, width: -1, height: -1)
            framesInfo[href] = hrefFrame
        }
        Logger.shared.logInfo("registerhref: framesInfo=\(framesInfo)", category: .pointAndShoot)
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
