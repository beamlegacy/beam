//
//  WebFieldLocator.swift
//  Beam
//
//  Created by Frank Lefebvre on 23/03/2022.
//

import Foundation
import Combine
import BeamCore

/// Publishes the position of the requested DOM element relative to the web view.
final class WebFieldLocator {
    private let JSObjectName = "PasswordManager"
    private let decoder: BeamJSONDecoder = .init()

    private weak var page: WebPage?
    let elementId: String
    private weak var frameInfo: WKFrameInfo?
    private var parentFrames: [String: WebFrames.FrameInfo]
    private var subscription: AnyCancellable?
    private var scope = Set<AnyCancellable>()

    private var fieldFrameSubject = CurrentValueSubject<CGRect, Never>(.zero)

    var fieldFramePublisher: AnyPublisher<CGRect, Never> {
        fieldFrameSubject.eraseToAnyPublisher()
    }

    var currentValue: CGRect {
        fieldFrameSubject.value
    }

    init(page: WebPage?, elementId: String, frameInfo: WKFrameInfo?, scrollUpdater: PassthroughSubject<WebFrames.FrameInfo, Never>) {
        self.page = page
        self.elementId = elementId
        self.frameInfo = frameInfo
        if let frameURL = frameInfo?.request.url?.absoluteString {
            parentFrames = page?.webFrames?.framesInPath(href: frameURL) ?? [:]
        } else {
            parentFrames = [:]
        }
        if !parentFrames.isEmpty {
            scrollUpdater
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { [weak self] frame in
                    self?.updateScrollPosition(frame)
                })
                .store(in: &scope)
        }
        updateFieldPosition()
    }

    private func updateScrollPosition(_ frame: WebFrames.FrameInfo) {
        guard let movedFrame = parentFrames[frame.href] else {
            return
        }
        let dx = frame.scrollX - movedFrame.scrollX
        let dy = frame.scrollY - movedFrame.scrollY
        guard dx != 0 || dy != 0 else {
            return
        }
        parentFrames[frame.href] = frame
        guard frameInfo != nil else {
            return
        }
        updateFieldPosition()
    }

    private func updateFieldPosition() {
        requestWebFieldFrame(elementId: elementId, frameInfo: frameInfo) { rect in
            guard let page = self.page,
                  let webView = (page as? BrowserTab)?.webView,
                  let rect = rect
            else { return }
            self.fieldFrameSubject.send(self.convertRect(rect, relativeTo: webView))
        }
    }

    private func requestWebFieldFrame(elementId: String, frameInfo: WKFrameInfo?, completion: @escaping (CGRect?) -> Void) {
        let script = "passwordHelper.getElementRects('[\"\(elementId)\"]')"
        self.page?.executeJS(script, objectName: JSObjectName, frameInfo: frameInfo).then { [weak self] jsResult in
            guard let self = self, let jsonString = jsResult as? String, let jsonData = jsonString.data(using: .utf8), let rects = try? self.decoder.decode([DOMRect?].self, from: jsonData), let rect = rects.first??.rect else {
                return completion(nil)
            }
            let offset: CGPoint
            if let href = frameInfo?.request.url?.absoluteString, let webPositions = self.page?.webPositions {
                offset = webPositions.viewportOffset(href: href)
            } else {
                offset = .zero
            }
            let scale = self.page?.webView.zoomLevel() ?? 1
            Logger.shared.logDebug("Frame for \(elementId): \(rect), with offset \(offset), scale: \(scale)", category: .passwordManagerInternal)
            let frame = CGRect(x: (rect.minX + offset.x) * scale, y: (rect.minY + offset.y) * scale, width: rect.width * scale, height: rect.height * scale)
            completion(frame)
        }
    }

    private func convertRect(_ rect: CGRect, relativeTo webView: WKWebView) -> CGRect {
        var rect = webView.convert(rect, to: nil)
        rect.origin.y -= webView.topContentInset
        return rect
    }
}
