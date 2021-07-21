import Foundation
import BeamCore

enum PointAndShootMessages: String, CaseIterable {
    case pointAndShoot_pointBounds
    case pointAndShoot_shootBounds
    case pointAndShoot_selectBounds
    case pointAndShoot_hasSelection
    case pointAndShoot_pinch
    case pointAndShoot_frameBounds
    case pointAndShoot_scroll
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
            guard let pointAndShoot = webPage.pointAndShoot else { throw PointAndShootError("webPage should have a pointAndShoot component") }
            guard webPage.pointAndShootAllowed == true else { throw PointAndShootError("Point and shoot is not allowed on this page") }
            guard let dict = messageBody as? [String: AnyObject],
                  let href = dict["href"] as? String else {
                throw PointAndShootError("href payload is incorrect")
            }

            switch messageKey {
            case PointAndShootMessages.pointAndShoot_pointBounds:
                guard let pointBounds = dict["point"] as? [String: AnyObject],
                      let targets = boundsToTargets([pointBounds], webPage, href, animated: true) else { throw PointAndShootError("point payload incomplete") }

                if let target = targets.first {
                    pointAndShoot.point(target, href)
                }

            case PointAndShootMessages.pointAndShoot_shootBounds:
                guard let shootBounds = dict["shoot"] as? [[String: AnyObject]],
                      let targets = boundsToTargets(shootBounds, webPage, href, animated: false) else { throw PointAndShootError("shoot payload incomplete") }

                for target in targets {
                    pointAndShoot.pointShoot(target.id, target, href)
                }

            case PointAndShootMessages.pointAndShoot_hasSelection:
                guard let hasSelection = dict["hasSelection"] as? Bool else { throw PointAndShootError("hasSelection payload incomplete") }
                pointAndShoot.hasActiveSelection = hasSelection

            case PointAndShootMessages.pointAndShoot_selectBounds:
                guard let selectBounds = dict["select"] as? [[String: AnyObject]]
                    else { throw PointAndShootError("select payload incomplete") }

                for bounds in selectBounds {
                    if let id = bounds["id"] as? String,
                       let targetData = bounds["rectData"] as? [[String: AnyObject]],
                       let targets = boundsToTargets(targetData, webPage, href, animated: false) {
                        pointAndShoot.select(id, targets, href)
                    }
                }

            case PointAndShootMessages.pointAndShoot_pinch:
                guard let scale = dict["scale"] as? CGFloat else { return }
                pointAndShoot.webPositions.scale = scale

            case PointAndShootMessages.pointAndShoot_scroll:
                guard let x = dict["x"] as? CGFloat,
                      let y = dict["y"] as? CGFloat,
                      let href = dict["href"] as? String,
                      let scale = dict["scale"] as? CGFloat else {
                    Logger.shared.logError("Ignored scroll event: \(String(describing: dict))", category: .web)
                    return
                }
                pointAndShoot.webPositions.scale = scale
                pointAndShoot.webPositions.setFrameInfoScroll(href: href, scrollX: x, scrollY: y)

            case PointAndShootMessages.pointAndShoot_frameBounds:
                onFramesInfoMessage(dict: dict, positions: pointAndShoot.webPositions, href: href)
            }

        } catch {
            Logger.shared.logError("Message error: \(error)", category: .pointAndShoot)
            return
        }
    }

    private func onFramesInfoMessage(dict: [String: AnyObject], positions: WebPositions, href: String) {
        guard let jsFramesInfo = dict["frames"] as? NSArray else {
            Logger.shared.logError("Ignored beam_frameBounds: \(String(describing: dict))", category: .web)
            return
        }

        for jsFrameInfo in jsFramesInfo {
            let jsFrameInfo = jsFrameInfo as AnyObject
            let bounds = jsFrameInfo["bounds"] as AnyObject
            if let frameHref = jsFrameInfo["href"] as? String {
                let rectArea = positions.jsToRect(jsArea: bounds)

                let frame = WebPositions.FrameInfo(
                    href: frameHref,
                    parentHref: href,
                    x: rectArea.minX,
                    y: rectArea.minY,
                    width: rectArea.width,
                    height: rectArea.height
                )

                positions.setFrameInfo(frame: frame)
            }
        }
    }

    func boundsToTargets(_ bounds: [[String: AnyObject]], _ webPage: WebPage, _ href: String, animated: Bool) -> [PointAndShoot.Target]? {
        guard let pointAndShoot = webPage.pointAndShoot else {
            Logger.shared.logDebug("Bounds payload can't be unwrapped")
            return nil
        }

        return bounds.compactMap { element -> PointAndShoot.Target? in
            let rectObject = element["rect"] as AnyObject
            let rect = pointAndShoot.webPositions.jsToRect(jsArea: rectObject)
            if let html = element["html"] as? String,
               let id = element["id"] as? String {
                return pointAndShoot.createTarget(id, rect, html, href, animated)
            }
            return nil
        }
    }
}
