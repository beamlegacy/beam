//
//  FormatterView.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 03/01/2021.
//

import Cocoa

// Base Class for any formatting view
class FormatterView: NSView {

    static let appearAnimationDuration = 0.3
    static let disappearAnimationDuration = 0.15

    internal var viewType: FormatterViewType = .persistent

    var idealSize: NSSize {
        return .zero
    }

    var isMouseInsideView = false

    convenience init(viewType: FormatterViewType) {
        self.init(frame: .zero)
        self.viewType = viewType
    }

    func setupLayer() {
        self.wantsLayer = true
    }

    func animateOnAppear(completionHandler: (() -> Void)? = nil) { }

    func animateOnDisappear(completionHandler: (() -> Void)? = nil) { }

    private var customTrackingArea: NSTrackingArea?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let previousArea = customTrackingArea {
            self.removeTrackingArea(previousArea)
        }
        let newArea = NSTrackingArea(
            rect: self.bounds,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
            owner: self, userInfo: ["view": self]
        )
        customTrackingArea = newArea
        self.addTrackingArea(newArea)
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isMouseInsideView = true
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isMouseInsideView = false
    }
}

class FormatterViewViewModel: ObservableObject {
    @Published var visible: Bool = false
}
