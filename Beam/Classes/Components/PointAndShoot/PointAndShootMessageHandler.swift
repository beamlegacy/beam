import Foundation
import BeamCore

struct FrameInfo {
    let origin: String
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
     Validate a pointed block for selection.
     */
    case pointAndShoot_shoot
    case pointAndShoot_shootConfirmation
    /**
     Ongoing text highlighting
     */
    case pointAndShoot_textSelection
    /**
     Completed text highlight
     */
    case pointAndShoot_textSelected
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

    override func onMessage(messageName: String, messageBody: [String: AnyObject]?, from webPage: WebPage) {
        let pointAndShoot = webPage.pointAndShoot!
        let positions = pointAndShoot.webPositions
        switch messageName {

        case PointAndShootMessages.pointAndShoot_onLoad.rawValue:
            Logger.shared.logInfo("onLoad flushing frameInfo", category: .web)
            positions.framesInfo.removeAll()

        case PointAndShootMessages.pointAndShoot_point.rawValue:
            guard webPage.pointAndShootAllowed else { return }
            guard let dict = messageBody,
                  let origin = dict["origin"] as? String,
                  let area = areaValue(of: dict, from: webPage),
                  let (location, html) = targetValues(of: dict, from: webPage) else {
                pointAndShoot.unpoint()
                return
            }
            let pointArea = positions.viewportArea(area: area, origin: origin)
            let target = PointAndShoot.Target(area: pointArea, mouseLocation: location, html: html)
            pointAndShoot.point(target: target)
            Logger.shared.logInfo("Web block point: \(pointArea)", category: .web)

        case PointAndShootMessages.pointAndShoot_shoot.rawValue:
            guard webPage.pointAndShootAllowed == true else { return }
            guard let dict = messageBody,
                  let area = areaValue(of: dict, from: webPage),
                  let (location, html) = targetValues(of: dict, from: webPage),
                  let origin = dict["origin"] as? String else {
                Logger.shared.logError("Ignored shoot event: \(String(describing: messageBody))", category: .web)
                return
            }
            let target = PointAndShoot.Target(area: area, mouseLocation: location, html: html)
            pointAndShoot.shoot(targets: [target], origin: origin)
            Logger.shared.logInfo("Web shoot point: \(area)", category: .web)

        case PointAndShootMessages.pointAndShoot_shootConfirmation.rawValue:
            guard webPage.pointAndShootAllowed == true else { return }
            guard let dict = messageBody,
                  let area = areaValue(of: dict, from: webPage),
                  // let (location, html) = pointAndShootTargetValues(from: dict),
                  let _ = dict["origin"] as? String else {
                Logger.shared.logError("Ignored shoot event: \(String(describing: messageBody))", category: .web)
                return
            }
            // let target = PointAndShoot.Target(area: area, mouseLocation: location, html: html)
            pointAndShoot.showShootInfo(group: pointAndShoot.currentGroup!)
            Logger.shared.logInfo("Web shoot confirmation: \(area)", category: .web)

        case PointAndShootMessages.pointAndShoot_textSelected.rawValue:
            guard webPage.pointAndShootAllowed == true else { return }
            guard let dict = messageBody,
                  dict["index"] as? Int != nil,
                  dict["text"] as? String != nil,
                  let origin = dict["origin"] as? String,
                  let html = dict["html"] as? String,
                  let areas = areasValue(of: dict, from: webPage),
                  !html.isEmpty else {
                Logger.shared.logError("Ignored text selected event: \(String(describing: messageBody))",
                                       category: .web)
                return
            }
            let targets = areas.map {
                PointAndShoot.Target(area: $0, mouseLocation: CGPoint(x: $0.minX, y: $0.maxY), html: html)
            }
            Logger.shared.logInfo("Web text selected, shooting targets: \(targets)", category: .web)
            pointAndShoot.shoot(targets: targets, origin: origin, done: true)

        case PointAndShootMessages.pointAndShoot_textSelection.rawValue:
            guard webPage.pointAndShootAllowed == true else { return }
            guard let dict = messageBody,
                  dict["index"] as? Int != nil,
                  dict["text"] as? String != nil,
                  let origin = dict["origin"] as? String,
                  let html = dict["html"] as? String,
                  let areas = areasValue(of: dict, from: webPage),
                  !html.isEmpty
                    else {
                Logger.shared.logError("Ignored text selection event: \(String(describing: messageBody))",
                                       category: .web)
                return
            }
            let targets = areas.map {
                PointAndShoot.Target(area: $0,
                                     mouseLocation: CGPoint(x: $0.minX, y: $0.maxY), html: html)
            }
            Logger.shared.logInfo("Web text selection, shooting targets: \(targets)", category: .web)
            pointAndShoot.shoot(targets: targets, origin: origin, done: false)

        case PointAndShootMessages.pointAndShoot_pinch.rawValue:
            guard let dict = messageBody,
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
            guard let dict = messageBody,
                  let x = dict["x"] as? CGFloat,
                  let y = dict["y"] as? CGFloat,
                  let width = dict["width"] as? CGFloat,
                  let height = dict["height"] as? CGFloat,
                  let _ = dict["origin"] as? String,
                  let scale = dict["scale"] as? CGFloat
                    else {
                Logger.shared.logError("Ignored scroll event: \(String(describing: messageBody))", category: .web)
                return
            }
            positions.scale = scale
            var page = webPage
            page.scrollX = x // nativeX(x: x, origin: origin)
            page.scrollY = y // nativeY(y: y, origin: origin)
            if pointAndShoot.isPointing {
                // Logger.shared.logDebug("scroll redraw because pointing", pointAndShoot)
                pointAndShoot.drawAllGroups()
            } else {
                Logger.shared.logDebug("scroll NOT redraw because pointing=\(pointAndShoot.status)",
                                       category: .pointAndShoot)
            }
            Logger.shared.logDebug("Web Scrolled: \(webPage.scrollX), \(webPage.scrollY)", category: .web)

        case PointAndShootMessages.pointAndShoot_frameBounds.rawValue:
            guard let dict = messageBody,
                  let jsFramesInfo = dict["frames"] as? NSArray
                    else {
                Logger.shared.logError("Ignored beam_frameBounds: \(String(describing: messageBody))", category: .web)
                return
            }
            for jsFrameInfo in jsFramesInfo {
                let d = jsFrameInfo as AnyObject
                let bounds = d["bounds"] as AnyObject
                if let origin = d["origin"] as? String,
                   let href = d["href"] as? String {
                    positions.registerOrigin(origin: origin)
                    let rectArea = positions.jsToRect(jsArea: bounds)
                    let nativeBounds = positions.viewportArea(area: rectArea, origin: origin)
                    positions.framesInfo[href] = FrameInfo(
                            origin: origin, x: nativeBounds.minX, y: nativeBounds.minY,
                            width: nativeBounds.width, height: nativeBounds.height
                    )
                }
            }

        case PointAndShootMessages.pointAndShoot_resize.rawValue:
            guard let dict = messageBody,
                  let width = dict["width"] as? CGFloat,
                  let height = dict["height"] as? CGFloat,
                  let origin = dict["origin"] as? String
                    else {
                Logger.shared.logError("Ignored beam_resize: \(String(describing: messageBody))", category: .web)
                return
            }
            // pointAndShoot.drawCurrentGroup()

        case PointAndShootMessages.pointAndShoot_setStatus.rawValue:
            guard let dict = messageBody,
                  let status = dict["status"] as? String,
                  let _ = dict["origin"] as? String
                    else {
                Logger.shared.logError("Ignored beam_status: \(String(describing: messageBody))", category: .web)
                return
            }
            pointAndShoot.status = PointAndShootStatus(rawValue: status)!

        default:
            break
        }
    }

    func targetValues(of jsMessage: [String: AnyObject], from webPage: WebPage) -> (location: NSPoint, html: String)? {
        guard let html = jsMessage["html"] as? String,
              let location = jsMessage["location"] else {
            return nil
        }
        let position = webPage.pointAndShoot!.webPositions.jsToPoint(jsPoint: location)
        return (position, html)
    }

    func areaValue(of jsMessage: [String: AnyObject], from webPage: WebPage) -> NSRect? {
        guard let area = jsMessage["area"] else {
            return nil
        }
        return webPage.pointAndShoot!.webPositions.jsToRect(jsArea: area)
    }

    func areasValue(of jsMessage: [String: AnyObject], from webPage: WebPage) -> [NSRect]? {
        guard let areas = jsMessage["areas"] as? [AnyObject] else {
            return nil
        }
        return areas.map { webPage.pointAndShoot!.webPositions.jsToRect(jsArea: $0) }
    }
}
