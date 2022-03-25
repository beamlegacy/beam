//
//  WebAutofillPopoverContainer.swift
//  Beam
//
//  Created by Frank Lefebvre on 04/02/2022.
//

import Foundation
import Combine
import BeamCore

final class WebAutofillPopoverContainer {
    let window: PopoverWindow
    private weak var page: WebPage?
    private let topEdgeHeight: CGFloat?
    private let fieldLocator: WebFieldLocator
    private let originCalculator: (CGRect) -> CGPoint
    private var scope = Set<AnyCancellable>()

    init(window: PopoverWindow, page: WebPage, topEdgeHeight: CGFloat? = nil, fieldLocator: WebFieldLocator, originCalculator: @escaping (CGRect) -> CGPoint) {
        self.window = window
        self.page = page
        self.topEdgeHeight = topEdgeHeight
        self.fieldLocator = fieldLocator
        self.originCalculator = originCalculator
        fieldLocator.fieldFramePublisher
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] rect in
                guard let self = self else { return }
                self.updateWindowOrigin(self.originCalculator(rect))
            })
            .store(in: &scope)
    }

    var currentOrigin: CGPoint {
        originCalculator(fieldLocator.currentValue)
    }

    private func updateWindowOrigin(_ origin: CGPoint) {
        window.setOrigin(origin, fromTopLeft: true)
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
