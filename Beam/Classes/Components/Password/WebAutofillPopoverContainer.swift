//
//  WebAutofillPopoverContainer.swift
//  Beam
//
//  Created by Frank Lefebvre on 04/02/2022.
//

import Foundation
import Combine

final class WebAutofillPopoverContainer {
    private let window: PopoverWindow
    private weak var page: WebPage?
    private let topEdgeHeight: CGFloat?
    private var parentFrames: [String: WebPositions.FrameInfo]
    private var subscription: AnyCancellable?

    init(window: PopoverWindow, page: WebPage, frameURL: String?, scrollUpdater: PassthroughSubject<WebPositions.FrameInfo, Never>, topEdgeHeight: CGFloat? = nil) {
        self.window = window
        self.page = page
        self.topEdgeHeight = topEdgeHeight
        if let frameURL = frameURL {
            parentFrames = page.webPositions?.framesInPath(href: frameURL) ?? [:]
        } else {
            parentFrames = [:]
        }
        if !parentFrames.isEmpty {
            subscription = scrollUpdater
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: updateScrollPosition)
        }
    }

    private func updateScrollPosition(_ frame: WebPositions.FrameInfo) {
        guard let movedFrame = parentFrames[frame.href] else {
            return
        }
        let dx = frame.scrollX - movedFrame.scrollX
        let dy = frame.scrollY - movedFrame.scrollY
        guard dx != 0 || dy != 0 else {
            return
        }
        let scale = page?.webView.zoomLevel() ?? 1
        let x = window.frame.origin.x - dx * scale
        let y = window.frame.origin.y + dy * scale
        window.setFrameOrigin(CGPoint(x: x, y: y))
        parentFrames[frame.href] = frame
        window.alphaValue = isWindowWithinParent() ? 1.0 : 0.0 // window.setIsVisible(false) causes the window to lose its parent
    }

    private func isWindowWithinParent() -> Bool {
        guard let parent = window.parent else {
            return true
        }
        let parentFrame: CGRect
        if let contentFrame = page?.frame {
            parentFrame = parent.convertToScreen(contentFrame)
        } else {
            parentFrame = parent.frame
        }
        let windowFrame: CGRect
        if let topEdgeHeight = topEdgeHeight {
            windowFrame = CGRect(x: window.frame.origin.x, y: window.frame.origin.y + window.frame.size.height - topEdgeHeight, width: window.frame.size.width, height: topEdgeHeight)
        } else {
            windowFrame = window.frame
        }
        return parentFrame.contains(windowFrame)
    }

    func orderFront() {
        guard let parentWindow = window.parent else {
            return
        }
        parentWindow.removeChildWindow(window)
        parentWindow.addChildWindow(window, ordered: .above)
    }
}
