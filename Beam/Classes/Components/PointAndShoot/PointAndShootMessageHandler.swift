import Foundation
import BeamCore

struct FrameInfo {
    let href: String
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
}

enum PointAndShootMessages: String, CaseIterable {
    /**
     Hover a block with Option key.
     */
    case pointAndShoot_point
    /**
     Clears point UI without changing any stored state
     */
    case pointAndShoot_hidePoint
    /**
     Selection of text or block
     */
    case pointAndShoot_select
    /**
     Validate a pointed block for selection.
     */
    case pointAndShoot_shoot
    case pointAndShoot_shootConfirmation
    /**
     Completed text highlight
     */
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
        super.init(config: config, messages: PointAndShootMessages.self, jsFileName: "index_prod", cssFileName: "index_prod")
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    override func onMessage(messageName: String, messageBody: Any?, from webPage: WebPage) {
        let pnsBody = messageBody as? [String: AnyObject]
        let pointAndShoot = webPage.pointAndShoot
        let positions = pointAndShoot.webPositions
        switch messageName {

        case PointAndShootMessages.pointAndShoot_onLoad.rawValue:
            Logger.shared.logInfo("onLoad flushing frameInfo", category: .web)
            positions.framesInfo.removeAll()

        case PointAndShootMessages.pointAndShoot_point.rawValue:
            guard webPage.pointAndShootAllowed == true else { return }
            guard let dict = pnsBody,
                  let href = dict["href"] as? String,
                  let areas = areasValue(of: dict, from: webPage),
                  let (location, html) = targetValues(of: dict, from: webPage) else {
                pointAndShoot.unpoint()
                return
            }
            let quoteId = pointAndShootQuoteIdValue(from: dict)
            if let area = areas.first {
                let pointArea = positions.viewportArea(area: area, href: href)
                let target = pointAndShoot.createTarget(area: area, quoteId: quoteId, mouseLocation: location, html: html)
                pointAndShoot.point(target: target)
                Logger.shared.logInfo("Web block point: \(pointArea)", category: .web)
            }

        case PointAndShootMessages.pointAndShoot_hidePoint.rawValue:
            guard webPage.pointAndShootAllowed == true else { return }
            pointAndShoot.hidePoint()

        case PointAndShootMessages.pointAndShoot_shoot.rawValue:
            guard webPage.pointAndShootAllowed == true else { return }
            guard let dict = pnsBody,
                  let areas = areasValue(of: dict, from: webPage),
                  let (location, html) = targetValues(of: dict, from: webPage),
                  let href = dict["href"] as? String else {
                Logger.shared.logError("Ignored shoot event: \(String(describing: pnsBody))", category: .web)
                return
            }
            let quoteId = pointAndShootQuoteIdValue(from: dict)
            let targets = areas.map { area -> PointAndShoot.Target in
                Logger.shared.logInfo("Web shoot point: \(area)", category: .web)
                return pointAndShoot.createTarget(area: area, quoteId: quoteId, mouseLocation: location, html: html)
            }
            pointAndShoot.shoot(targets: targets, href: href)

        case PointAndShootMessages.pointAndShoot_shootConfirmation.rawValue:
            guard webPage.pointAndShootAllowed == true else { return }
            guard let dict = pnsBody,
                  let areas = areasValue(of: dict, from: webPage),
                  dict["href"] as? String != nil else {
                Logger.shared.logError("Ignored shoot event: \(String(describing: pnsBody))", category: .web)
                return
            }
            pointAndShoot.showShootInfo(group: pointAndShoot.activeShootGroup!)
            Logger.shared.logInfo("Web shoot confirmation: \(areas)", category: .web)

        case PointAndShootMessages.pointAndShoot_select.rawValue:
            guard webPage.pointAndShootAllowed == true else { return }
            guard let dict = pnsBody,
                  dict["text"] as? String != nil,
                  let href = dict["href"] as? String,
                  let html = dict["html"] as? String,
                  let areas = areasValue(of: dict, from: webPage),
                  !html.isEmpty else {
                Logger.shared.logError("Ignored text selected event: \(String(describing: pnsBody))",
                                       category: .web)
                return
            }
            let targets = areas.map { area -> PointAndShoot.Target in
                let x: CGFloat = 0
                let y: CGFloat = area.maxY - area.minY
                return pointAndShoot.createTarget(area: area, mouseLocation: CGPoint(x: x, y: y), html: html)
            }
            Logger.shared.logInfo("Web text selected, shooting targets: \(targets)", category: .web)
            pointAndShoot.shoot(targets: targets, href: href)

        case PointAndShootMessages.pointAndShoot_pinch.rawValue:
            guard let dict = pnsBody,
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

        case PointAndShootMessages.pointAndShoot_scroll.rawValue:
            guard let dict = pnsBody,
                  let x = dict["x"] as? CGFloat,
                  let y = dict["y"] as? CGFloat,
                  dict["width"] as? CGFloat != nil,
                  dict["height"] as? CGFloat != nil,
                  dict["href"] as? String != nil,
                  let scale = dict["scale"] as? CGFloat
                    else {
                Logger.shared.logError("Ignored scroll event: \(String(describing: pnsBody))", category: .web)
                return
            }
            positions.scale = scale
            let page = webPage
            page.scrollX = x // nativeX(x: x, href: href)
            page.scrollY = y // nativeY(y: y, href: href)
            Logger.shared.logDebug("Web Scrolled: \(page.scrollX), \(page.scrollY)", category: .web)

        case PointAndShootMessages.pointAndShoot_frameBounds.rawValue:
            guard let dict = pnsBody,
                  let jsFramesInfo = dict["frames"] as? NSArray
                    else {
                Logger.shared.logError("Ignored beam_frameBounds: \(String(describing: pnsBody))", category: .web)
                return
            }
            for jsFrameInfo in jsFramesInfo {
                let d = jsFrameInfo as AnyObject
                let bounds = d["bounds"] as AnyObject
                if let windowHref = d["href"] as? String,
                   let href = d["href"] as? String {
                    positions.registerHref(href: windowHref)
                    let rectArea = positions.jsToRect(jsArea: bounds)
                    let nativeBounds = positions.viewportArea(area: rectArea, href: windowHref)
                    positions.framesInfo[href] = FrameInfo(
                            href: windowHref, x: nativeBounds.minX, y: nativeBounds.minY,
                            width: nativeBounds.width, height: nativeBounds.height
                    )
                }
            }

        case PointAndShootMessages.pointAndShoot_resize.rawValue:
            guard let dict = pnsBody,
                  let scale = dict["scale"] as? CGFloat,
                  let selectedElements = dict["selected"] as? [[String: AnyObject]],
                  let href = dict["href"] as? String else {
                Logger.shared.logError("Ignored beam_resize: \(String(describing: pnsBody))", category: .web)
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
                        return pointAndShoot.createTarget(area: area, quoteId: quoteId, mouseLocation: location, html: html)
                    }
                }
                return nil
            }.flatMap { $0 }
            pointAndShoot.updateShoots(targets: newTargets, href: href)

        case PointAndShootMessages.pointAndShoot_setStatus.rawValue:
            guard let dict = pnsBody,
                  let status = dict["status"] as? String,
                  dict["href"] as? String != nil
                    else {
                Logger.shared.logError("Ignored beam_status: \(String(describing: pnsBody))", category: .web)
                return
            }
            pointAndShoot.status = PointAndShootStatus(rawValue: status)!

        default:
            break
        }

        // After recieving any web events, draw PNS
        pointAndShoot.draw()
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
}
