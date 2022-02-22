//
//  WebPositionsMessageHandler.swift
//  Beam
//
//  Created by Stef Kors on 27/10/2021.
//

import Foundation
import BeamCore

enum WebPositionsMessages: String, CaseIterable {
    case WebPositions_frameBounds
    case WebPositions_scroll
}

struct WebPositionsError: LocalizedError {
    var errorDescription: String?
    var failureReason: String?
    var recoverySuggestion: String?
    var helpAnchor: String?

    init(_ desc: String, reason: String? = nil, suggestion: String? = nil, help: String? = nil) {
        errorDescription = desc
        failureReason = reason
        recoverySuggestion = suggestion
        helpAnchor = help
    }
}

class WebPositionsMessageHandler: SimpleBeamMessageHandler {

    init() {
        let messages = WebPositionsMessages.self.allCases.map { $0.rawValue }
        super.init(messages: messages, jsFileName: "WebPositions_prod")
    }

    override func onMessage(messageName: String, messageBody: Any?, from webPage: WebPage, frameInfo: WKFrameInfo?) {
        do {
            guard let webPositions = webPage.webPositions else {
                throw WebPositionsError("webPositions is required")
            }
            guard let messageKey = WebPositionsMessages(rawValue: messageName) else {
                Logger.shared.logError("Unsupported message '\(messageName)' for WebPostions message handler", category: .web)
                return
            }
            guard let dict = messageBody as? [String: AnyObject],
                  let href = dict["href"] as? String else {
                      throw WebPositionsError("href payload is incorrect")
            }

            switch messageKey {
            case WebPositionsMessages.WebPositions_scroll:
                guard let x = dict["x"] as? CGFloat,
                      let y = dict["y"] as? CGFloat,
                      let href = dict["href"] as? String else {
                          Logger.shared.logError("Ignored scroll event: \(String(describing: dict))", category: .web)
                          return
                      }

                webPositions.setFrameInfoScroll(href: href, scrollX: x, scrollY: y)

            case WebPositionsMessages.WebPositions_frameBounds:
                onFramesInfoMessage(dict: dict, positions: webPositions, href: href)
            }

        } catch {
            Logger.shared.logError("Message error: \(error)", category: .web)
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
                let rectArea = jsToRect(jsArea: bounds)

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
}
