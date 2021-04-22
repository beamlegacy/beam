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
 Handles messages sent from web page's javascript.
 */
class PointAndShootMessageHandler: NSObject, WKScriptMessageHandler {

    let webPositions: WebPositions
    let pointAndShoot: PointAndShoot
    var page: WebPage

    init(page: WebPage, webPositions: WebPositions, pointAndShoot: PointAndShoot) {
        self.page = page
        self.webPositions = webPositions
        self.pointAndShoot = pointAndShoot
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let messageBody = message.body as? [String: AnyObject]
        let messageKey = message.name
        let messageName = messageKey // .components(separatedBy: "_beam_")[1]
        switch messageName {

        case PointAndShootMessages.pointAndShoot_onLoad.rawValue:
            Logger.shared.logInfo("onLoad flushing frameInfo", category: .web)
            webPositions.framesInfo.removeAll()

        case PointAndShootMessages.pointAndShoot_point.rawValue:
            guard page.pointAndShootAllowed else { return }
            guard let dict = messageBody,
                  let origin = dict["origin"] as? String,
                  let area = pointAndShootAreaValue(from: dict),
                  let (location, html) = pointAndShootTargetValues(from: dict) else {
                pointAndShoot.unpoint()
                return
            }
            let pointArea = webPositions.viewportArea(area: area, origin: origin)
            let target = PointAndShoot.Target(area: pointArea, mouseLocation: location, html: html)
            pointAndShoot.point(target: target)
            Logger.shared.logInfo("Web block point: \(pointArea)", category: .web)

        case PointAndShootMessages.pointAndShoot_shoot.rawValue:
            guard page.pointAndShootAllowed == true else { return }
            guard let dict = messageBody,
                  let area = pointAndShootAreaValue(from: dict),
                  let (location, html) = pointAndShootTargetValues(from: dict),
                  let origin = dict["origin"] as? String else {
                Logger.shared.logError("Ignored shoot event: \(String(describing: messageBody))", category: .web)
                return
            }
            let target = PointAndShoot.Target(area: area, mouseLocation: location, html: html)
            pointAndShoot.shoot(targets: [target], origin: origin)
            Logger.shared.logInfo("Web shoot point: \(area)", category: .web)

        case PointAndShootMessages.pointAndShoot_shootConfirmation.rawValue:
            guard page.pointAndShootAllowed == true else { return }
            guard let dict = messageBody,
                  let area = pointAndShootAreaValue(from: dict),
                  // let (location, html) = pointAndShootTargetValues(from: dict),
                  let _ = dict["origin"] as? String else {
                Logger.shared.logError("Ignored shoot event: \(String(describing: messageBody))", category: .web)
                return
            }
            // let target = PointAndShoot.Target(area: area, mouseLocation: location, html: html)
            pointAndShoot.showShootInfo(group: pointAndShoot.currentGroup!)
            Logger.shared.logInfo("Web shoot confirmation: \(area)", category: .web)

        case PointAndShootMessages.pointAndShoot_textSelected.rawValue:
            guard page.pointAndShootAllowed == true else { return }
            guard let dict = messageBody,
                  dict["index"] as? Int != nil,
                  dict["text"] as? String != nil,
                  let origin = dict["origin"] as? String,
                  let html = dict["html"] as? String,
                  let areas = pointAndShootAreasValue(from: dict),
                  !html.isEmpty else {
                Logger.shared.logError("Ignored text selected event: \(String(describing: messageBody))",
                                       category: .web)
                return
            }
            let targets = areas.map {
                PointAndShoot.Target(area: $0, mouseLocation: CGPoint(x: $0.minX, y: $0.maxY), html: html)
            }
            pointAndShoot.shoot(targets: targets, origin: origin, done: true)

        case PointAndShootMessages.pointAndShoot_textSelection.rawValue:
            guard page.pointAndShootAllowed == true else { return }
            guard let dict = messageBody,
                  dict["index"] as? Int != nil,
                  dict["text"] as? String != nil,
                  let origin = dict["origin"] as? String,
                  let html = dict["html"] as? String,
                  let areas = pointAndShootAreasValue(from: dict),
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
            webPositions.scale = scale

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
            webPositions.scale = scale
            page.scrollX = x // nativeX(x: x, origin: origin)
            page.scrollY = y // nativeY(y: y, origin: origin)
            if pointAndShoot.isPointing {
                // Logger.shared.logDebug("scroll redraw because pointing", pointAndShoot)
                pointAndShoot.drawAllGroups()
            } else {
                Logger.shared.logDebug("scroll NOT redraw because pointing=\(pointAndShoot.status)",
                                       category: .pointAndShoot)
            }
            Logger.shared.logDebug("Web Scrolled: \(page.scrollX), \(page.scrollY)", category: .web)

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
                    webPositions.registerOrigin(origin: origin)
                    let rectArea = webPositions.jsToRect(jsArea: bounds)
                    let nativeBounds = webPositions.viewportArea(area: rectArea, origin: origin)
                    webPositions.framesInfo[href] = FrameInfo(
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

    func register(to webView: WKWebView) {
        PointAndShootMessages.allCases.forEach {
            let handler = $0.rawValue
            webView.configuration.userContentController.add(self, name: handler)
            Logger.shared.logDebug("Added point and shoot cript handler: \(handler)", category: .web)
        }
        injectScripts()
    }

    private func injectScripts() {
        var jsCode = loadFile(from: "index_prod", fileType: "js")
        jsCode = "exports={};" + jsCode   // Hack to avoid commonJS code generation bug
        page.addJS(source: jsCode, when: .atDocumentEnd)

        let cssCode = loadFile(from: "index_prod", fileType: "css")
        page.addCSS(source: cssCode, when: .atDocumentEnd)
    }

    func unregister(from webView: WKWebView) {
        PointAndShootMessages.allCases.forEach {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: $0.rawValue)
        }
    }

    func pointAndShootTargetValues(from jsMessage: [String: AnyObject]) -> (location: NSPoint, html: String)? {
        guard let html = jsMessage["html"] as? String,
              let location = jsMessage["location"] else {
            return nil
        }
        let position = webPositions.jsToPoint(jsPoint: location)
        return (position, html)
    }

    func pointAndShootAreaValue(from jsMessage: [String: AnyObject]) -> NSRect? {
        guard let area = jsMessage["area"] else {
            return nil
        }
        return webPositions.jsToRect(jsArea: area)
    }

    func pointAndShootAreasValue(from jsMessage: [String: AnyObject]) -> [NSRect]? {
        guard let areas = jsMessage["areas"] as? [AnyObject] else {
            return nil
        }
        return areas.map { webPositions.jsToRect(jsArea: $0) }
    }

    func destroy(for webView: WKWebView) {
        self.unregister(from: webView)
    }
}
