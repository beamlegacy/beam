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
    case WebPositions_resize
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
            guard let webFrames = webPage.webFrames, let webPositions = webPage.webPositions else {
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
            case .WebPositions_scroll:
                guard let x = dict["x"] as? CGFloat,
                      let y = dict["y"] as? CGFloat,
                      let href = dict["href"] as? String else {
                          Logger.shared.logError("Ignored scroll event: \(String(describing: dict))", category: .web)
                          return
                      }

                webPositions.setFrameInfoScroll(href: href, scrollX: x, scrollY: y)

            case .WebPositions_resize:
                guard let width = dict["width"] as? CGFloat,
                      let height = dict["height"] as? CGFloat,
                      let href = dict["href"] as? String else {
                          Logger.shared.logError("Ignored resize event: \(String(describing: dict))", category: .web)
                          return
                      }

                webPositions.setFrameInfoResize(href: href, width: width, height: height)

            case .WebPositions_frameBounds:
                onFramesInfoMessage(dict: dict, frames: webFrames, positions: webPositions, href: href, isMain: frameInfo?.isMainFrame ?? false)
            }

        } catch {
            Logger.shared.logError("Message error: \(error)", category: .web)
            return
        }
    }

    private func onFramesInfoMessage(dict: [String: AnyObject], frames: WebFrames, positions: WebPositions, href: String, isMain: Bool) {
        guard let jsFramesInfo = dict["frames"] as? NSArray else {
            Logger.shared.logError("Ignored beam_frameBounds: \(String(describing: dict))", category: .web)
            return
        }

        var framesInfo = [WebFrames.FrameInfo]()
        for jsFrameInfo in jsFramesInfo {
            let jsFrameInfo = jsFrameInfo as AnyObject
            let bounds = jsFrameInfo["bounds"] as AnyObject
            let jsScrollSize = jsFrameInfo["scrollSize"] as AnyObject
            if let frameHref = jsFrameInfo["href"] as? String {
                let rectArea = jsToRect(jsArea: bounds)
                let size = jsToScrollSizing(jsSize: jsScrollSize)

                let frame = WebFrames.FrameInfo(
                    href: frameHref,
                    parentHref: href,
                    x: rectArea.minX,
                    y: rectArea.minY,
                    scrollWidth: size.width,
                    scrollHeight: size.height,
                    width: rectArea.width,
                    height: rectArea.height,
                    isMain: isMain && frameHref == href
                )

                framesInfo.append(frame)
            }
        }

        frames.setFrames(framesInfo, isMain: isMain)
    }

    private func jsToScrollSizing(jsSize: AnyObject) -> NSSize {
        guard let scrollWidth = jsSize["width"] as? CGFloat,
              let scrollHeight = jsSize["height"] as? CGFloat else {
            return .zero
        }
        return NSSize(width: scrollWidth, height: scrollHeight)
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
