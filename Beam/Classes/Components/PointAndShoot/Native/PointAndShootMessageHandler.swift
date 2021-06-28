import Foundation
import BeamCore

enum PointAndShootMessages: String, CaseIterable {
    /**
     Hover a block with Option key.
     */
    case pointAndShoot_point
    case pointAndShoot_cursor
    /**
     Selection of text or block
     */
    case pointAndShoot_select
    /**
     Validate a pointed block for selection.
     */
    case pointAndShoot_shoot
    /**
     Completed text highlight
     */
    case pointAndShoot_shootConfirmation
    case pointAndShoot_onLoad
    case pointAndShoot_scroll
    case pointAndShoot_resize
    case pointAndShoot_pinch
    case pointAndShoot_frameBounds
    case pointAndShoot_setStatus
}

/**
 Handles Point & shoot messages sent from web page's javascript.
 */
class PointAndShootMessageHandler: BeamMessageHandler<PointAndShootMessages> {

    init(config: BeamWebViewConfiguration) {
        super.init(config: config, messages: PointAndShootMessages.self, jsFileName: "index_prod")
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    override func onMessage(messageName: String, messageBody: Any?, from webPage: WebPage) {
        do {
            guard let messageKey = PointAndShootMessages(rawValue: messageName) else {
                Logger.shared.logError("Unsupported message \(messageName) for point and shoot message handler", category: .web)
                return
            }
            let msgPayload = messageBody as? [String: AnyObject]
            let pointAndShoot = webPage.pointAndShoot
            let positions = pointAndShoot.webPositions
            switch messageKey {

            case PointAndShootMessages.pointAndShoot_cursor:
                guard let dict = msgPayload,
                      let x = dict["x"] as? CGFloat,
                      let y = dict["y"] as? CGFloat,
                      let href = dict["href"] as? String else { return }

                let size: CGFloat = 20

                let target = pointAndShoot.createTarget(
                    area: NSRect(x: x - (size / 2), y: y - (size / 2), width: size, height: size),
                    quoteId: nil,
                    mouseLocation: NSPoint(x: x, y: y),
                    html: "nil",
                    href: href
                )

                pointAndShoot.cursor(target: target, href: href)

            case PointAndShootMessages.pointAndShoot_onLoad:
                onFramesInfoMessage(msgPayload: msgPayload, webPage: webPage, positions: positions)

            case PointAndShootMessages.pointAndShoot_point:
                try onPointMessage(msgPayload: msgPayload, webPage: webPage)

            case PointAndShootMessages.pointAndShoot_shoot:
                guard webPage.pointAndShootAllowed == true else { return }
                guard let dict = msgPayload,
                      let areas = areasValue(of: dict, from: webPage),
                      let (location, html) = targetValues(of: dict, from: webPage),
                      let href = dict["href"] as? String else {
                    Logger.shared.logError("Ignored shoot event: \(String(describing: msgPayload))", category: .pointAndShoot)
                    return
                }
                let quoteId = pointAndShootQuoteIdValue(from: dict)
                let targets = areas.map { area -> PointAndShoot.Target in
                    Logger.shared.logInfo("Web shoot point: \(area)", category: .pointAndShoot)
                    return pointAndShoot.createTarget(area: area, quoteId: quoteId, mouseLocation: location, html: html, href: href)
                }
                pointAndShoot.shoot(targets: targets, href: href)
                pointAndShoot.draw()

            case PointAndShootMessages.pointAndShoot_shootConfirmation:
                guard webPage.pointAndShootAllowed == true else { return }
                guard let dict = msgPayload,
                      let areas = areasValue(of: dict, from: webPage),
                      dict["href"] as? String != nil else {
                    Logger.shared.logError("Ignored shoot event: \(String(describing: msgPayload))", category: .pointAndShoot)
                    return
                }
                pointAndShoot.showShootInfo(group: pointAndShoot.activeShootGroup!)
                Logger.shared.logInfo("Web shoot confirmation: \(areas)", category: .pointAndShoot)

            case PointAndShootMessages.pointAndShoot_select:
                guard webPage.pointAndShootAllowed == true else { return }
                guard let dict = msgPayload,
                      dict["text"] as? String != nil,
                      let href = dict["href"] as? String,
                      let html = dict["html"] as? String,
                      let areas = areasValue(of: dict, from: webPage),
                      !html.isEmpty else {
                    Logger.shared.logError("Ignored text selected event: \(String(describing: msgPayload))",
                                           category: .pointAndShoot)
                    return
                }
                let targets = areas.map { area -> PointAndShoot.Target in
                    let x: CGFloat = 0
                    let y: CGFloat = area.maxY - area.minY
                    return pointAndShoot.createTarget(area: area, mouseLocation: CGPoint(x: x, y: y), html: html, href: href)
                }
                Logger.shared.logInfo("Web text selected, shooting targets: \(targets)", category: .pointAndShoot)
                pointAndShoot.ui.clearPoint()
                pointAndShoot.shoot(targets: targets, href: href)

            case PointAndShootMessages.pointAndShoot_pinch:
                guard let dict = msgPayload,
                      (dict["offsetLeft"] as? CGFloat) != nil,
                      (dict["pageLeft"] as? CGFloat) != nil,
                      (dict["offsetTop"] as? CGFloat) != nil,
                      (dict["pageTop"] as? CGFloat) != nil,
                      (dict["width"] as? CGFloat) != nil,
                      (dict["height"] as? CGFloat) != nil,
                      let scale = dict["scale"] as? CGFloat
                    else {
                    return
                }
                positions.scale = scale

            case PointAndShootMessages.pointAndShoot_scroll:
                guard let dict = msgPayload,
                      let x = dict["x"] as? CGFloat,
                      let y = dict["y"] as? CGFloat,
                      dict["width"] as? CGFloat != nil,
                      dict["height"] as? CGFloat != nil,
                      let href = dict["href"] as? String,
                      let scale = dict["scale"] as? CGFloat
                    else {
                    Logger.shared.logError("Ignored scroll event: \(String(describing: msgPayload))", category: .web)
                    return
                }
                positions.scale = scale
                positions.setFrameInfoScroll(href: href, scrollX: x, scrollY: y)
                pointAndShoot.draw()

            case PointAndShootMessages.pointAndShoot_frameBounds:
                onFramesInfoMessage(msgPayload: msgPayload, webPage: webPage, positions: positions)

            case PointAndShootMessages.pointAndShoot_resize:
                guard let dict = msgPayload,
                      let scale = dict["scale"] as? CGFloat,
                      let selectedElements = dict["selected"] as? [[String: AnyObject]],
                      let href = dict["href"] as? String else {
                    Logger.shared.logError("Ignored beam_resize: \(String(describing: msgPayload))", category: .web)
                    return
                }
                positions.scale = scale
                if selectedElements.count == 0 {
                    Logger.shared.logWarning("beam_resize selectedElements is empty. Skipping shoot updates", category: .web)
                    return
                }

                let newTargets = selectedElements.compactMap { element -> [PointAndShoot.Target]? in
                    if let areas = areasValue(of: element, from: webPage),
                       let (location, html) = targetValues(of: element, from: webPage) {
                        let quoteId = pointAndShootQuoteIdValue(from: element)
                        return areas.map { area -> PointAndShoot.Target in
                            pointAndShoot.createTarget(area: area, quoteId: quoteId, mouseLocation: location, html: html, href: href)
                        }
                    }
                    return nil
                }.flatMap { $0 }
                pointAndShoot.updateShoots(targets: newTargets, href: href)

            case PointAndShootMessages.pointAndShoot_setStatus:
                guard let dict = msgPayload,
                      let status = dict["status"] as? String,
                      let href = dict["href"] as? String else {
                    Logger.shared.logError("Ignored beam_status: \(String(describing: msgPayload))", category: .pointAndShoot)
                    return
                }

                _ = webPage.executeJS("syncStatus('\(status)')", objectName: "PointAndShoot")
                pointAndShoot.status = PointAndShootStatus(rawValue: status)!
            }

        } catch {
            Logger.shared.logError("Message error: \(error)", category: .pointAndShoot)
            return
        }
    }

    private func onFramesInfoMessage(msgPayload: [String: AnyObject]?, webPage: WebPage, positions: WebPositions) {
        guard let dict = msgPayload,
              let windowHref = dict["href"] as? String,
              let jsFramesInfo = dict["frames"] as? NSArray
        else {
            Logger.shared.logError("Ignored beam_frameBounds: \(String(describing: msgPayload))", category: .web)
            return
        }
        for jsFrameInfo in jsFramesInfo {
            let jsFrameInfo = jsFrameInfo as AnyObject
            let bounds = jsFrameInfo["bounds"] as AnyObject
            if let href = jsFrameInfo["href"] as? String {
                let rectArea = positions.jsToRect(jsArea: bounds)

                let frame = WebPositions.FrameInfo(
                    href: href,
                    parentHref: windowHref,
                    x: rectArea.minX,
                    y: rectArea.minY,
                    width: rectArea.width,
                    height: rectArea.height
                )

                _ = positions.setFrameInfo(frame: frame)
            }
        }
    }

    private func onPointMessage(msgPayload: [String: AnyObject]?, webPage: WebPage) throws {
        guard webPage.pointAndShootAllowed == true else { throw PointAndShootError("Point and shoot is not allowed on this page") }
        let pointAndShoot = webPage.pointAndShoot
        guard let dict = msgPayload,
              let href = dict["href"] as? String,
              let areas = areasValue(of: dict, from: webPage),
              let offset = offsetValue(of: dict, from: webPage),
              let (location, html) = targetValues(of: dict, from: webPage) else {
            pointAndShoot.unPoint()
            throw PointAndShootError("Point payload is incorrect")
        }
        let quoteId = pointAndShootQuoteIdValue(from: dict)
        if let area = areas.first {
            let target = pointAndShoot.createTarget(area: area, quoteId: quoteId, mouseLocation: location, html: html, offset: offset, href: href)
            pointAndShoot.point(target: target, href: href)
        }
    }

    func targetValues(of jsMessage: [String: AnyObject], from webPage: WebPage) -> (location: NSPoint, html: String)? {
        guard let html = jsMessage["html"] as? String,
              let location = jsMessage["location"] else {
            return nil
        }
        let position = webPage.pointAndShoot.webPositions.jsToPoint(jsPoint: location)
        return (position, html)
    }

    func pointAndShootQuoteIdValue(from jsMessage: [String: AnyObject]) -> UUID? {
        guard let quoteId = jsMessage["quoteId"] as? String else {
            return nil
        }
        return UUID(uuidString: quoteId)
    }

    func areasValue(of jsMessage: [String: AnyObject], from webPage: WebPage) -> [NSRect]? {
        guard let areas = jsMessage["areas"] as? [AnyObject] else {
            return nil
        }
        return areas.map { webPage.pointAndShoot.webPositions.jsToRect(jsArea: $0) }
    }

    func offsetValue(of jsMessage: [String: AnyObject], from webPage: WebPage) -> NSPoint? {
        guard let offset = jsMessage["offset"] else {
            return nil
        }
        return webPage.pointAndShoot.webPositions.jsToPoint(jsPoint: offset)
    }

}
