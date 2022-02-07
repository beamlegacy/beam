import Foundation
import BeamCore

enum PointAndShootMessages: String, CaseIterable {
    case pointAndShoot_pointBounds
    case pointAndShoot_shootBounds
    case pointAndShoot_selectBounds
    case pointAndShoot_clearSelection
    case pointAndShoot_hasSelection
    case pointAndShoot_isTypingOnWebView
    case pointAndShoot_dismissShootGroup
}

/**
 Handles Point & shoot messages sent from web page's javascript.
 */
class PointAndShootMessageHandler: BeamMessageHandler<PointAndShootMessages> {

    init(config: BeamWebViewConfiguration) {
        super.init(config: config, messages: PointAndShootMessages.self, jsFileName: "pns_prod")
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    override func onMessage(messageName: String, messageBody: Any?, from webPage: WebPage, frameInfo: WKFrameInfo?) {
        do {
            guard let messageKey = PointAndShootMessages(rawValue: messageName) else {
                Logger.shared.logError("Unsupported message \(messageName) for point and shoot message handler", category: .web)
                return
            }
            guard let pointAndShoot = webPage.pointAndShoot else { throw PointAndShootError("webPage should have a pointAndShoot component") }
            guard webPage.pointAndShootInstalled == true else { throw PointAndShootError("Point and shoot is not installed on this page") }
            guard let dict = messageBody as? [String: AnyObject],
                  let href = dict["href"] as? String else {
                throw PointAndShootError("href payload is incorrect")
            }

            switch messageKey {
            case PointAndShootMessages.pointAndShoot_pointBounds:
                guard let pointBounds = dict["point"] as? [String: AnyObject] else { throw PointAndShootError("point payload incomplete") }

                if let target = pointBoundsToTargets(pointBounds, webPage, href, animated: false) {
                    let text = pointBounds["text"] as? String ?? ""
                    pointAndShoot.point(target, text, href)
                }

            case PointAndShootMessages.pointAndShoot_shootBounds:
                guard let shootBounds = dict["shoot"] as? [[String: AnyObject]] else { throw PointAndShootError("shoot payload incomplete") }

                for shootBound in shootBounds {
                    if let target = pointBoundsToTargets(shootBound, webPage, href, animated: false) {
                        let text = shootBound["text"] as? String ?? ""
                        pointAndShoot.pointShoot(target.id, target, text, href)
                    }
                }

            case PointAndShootMessages.pointAndShoot_selectBounds:
                guard let selectBounds = dict["select"] as? [[String: AnyObject]]
                    else { throw PointAndShootError("select payload incomplete") }

                for bounds in selectBounds {
                    if let id = bounds["id"] as? String,
                       let html = bounds["html"] as? String,
                       let text = bounds["text"] as? String,
                       let targetData = bounds["rectData"] as? [[String: AnyObject]] {

                        if let targets = selectBoundsToTargets(targetData, webPage, href, html, animated: false) {
                            pointAndShoot.select(id, targets, text, href)
                        }
                    }
                }

            case PointAndShootMessages.pointAndShoot_clearSelection:
                guard let id = dict["id"] as? String else { throw PointAndShootError("clearSelection payload incomplete") }
                pointAndShoot.clearSelection(id)

            case PointAndShootMessages.pointAndShoot_hasSelection:
                let hasSelection = toBool(dict, key: "hasSelection")
                pointAndShoot.hasActiveSelection = hasSelection

            case PointAndShootMessages.pointAndShoot_isTypingOnWebView:
                let isTypingOnWebView = toBool(dict, key: "isTypingOnWebView")
                pointAndShoot.isTypingOnWebView = isTypingOnWebView

            case PointAndShootMessages.pointAndShoot_dismissShootGroup:
                guard let id = dict["id"] as? String
                else { throw PointAndShootError("dismiss payload incomplete") }
                pointAndShoot.dismissShootGroup(id: id, href: href)

            }

        } catch {
            Logger.shared.logError("Message error: \(error)", category: .pointAndShoot)
            return
        }
    }

    func pointBoundsToTargets(_ bounds: [String: AnyObject], _ webPage: WebPage, _ href: String, animated: Bool) -> PointAndShoot.Target? {
        guard let pointAndShoot = webPage.pointAndShoot,
              let id = bounds["id"] as? String else {
            Logger.shared.logDebug("Bounds payload can't be unwrapped")
            return nil
        }

        let rectObject = bounds["rect"] as AnyObject
        let html = bounds["html"] as? String ?? ""
        let rect = jsToRect(jsArea: rectObject)
        return pointAndShoot.createTarget(id, rect, html, href, animated)
    }

    func selectBoundsToTargets(_ bounds: [[String: AnyObject]], _ webPage: WebPage, _ href: String, _ html: String, animated: Bool) -> [PointAndShoot.Target]? {
        guard let pointAndShoot = webPage.pointAndShoot else {
            Logger.shared.logDebug("Bounds payload can't be unwrapped")
            return nil
        }

        let res = bounds.compactMap { element -> PointAndShoot.Target? in
            let rectObject = element["rect"] as AnyObject
            let rect = jsToRect(jsArea: rectObject)
            if let id = element["id"] as? String {
                return pointAndShoot.createTarget(id, rect, html, href, animated)
            }
            return nil
        }

        return res
    }

    private func toBool(_ dict: [String: AnyObject], key: String) -> Bool {
        return dict[key] as? Int == 1 ? true : false
    }

    /**
     - Parameter jsArea: a dictionary with x, y, width and height
     - Returns:
     */
    private func jsToRect(jsArea: AnyObject) -> NSRect {
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
    private func jsToPoint(jsPoint: AnyObject) -> NSPoint {
        guard let frameX = jsPoint["x"] as? CGFloat,
              let frameY = jsPoint["y"] as? CGFloat else {
                  return .zero
              }
        return NSPoint(x: frameX, y: frameY)
    }
}
