//
//  FormatterView.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 03/01/2021.
//

import Cocoa
import SwiftUI
import BeamCore

// Base Class for any formatting view
class FormatterView: NSView {

    static let appearAnimationDuration = 0.3
    static let disappearAnimationDuration = 0.15

    enum FormatterViewType {
        case inline
    }

    internal var key: String = ""
    internal var viewType: FormatterViewType = .inline

    var idealSize: CGSize {
        return .zero
    }

    var handlesTyping: Bool {
        false
    }

    var isMouseInsideView = false
    private var isVisible = false
    init(key: String, viewType: FormatterViewType) {
        super.init(frame: .zero)
        self.key = key
        self.viewType = viewType
        self.setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupUI() {
        self.wantsLayer = true
    }

    func animateOnAppear(completionHandler: (() -> Void)? = nil) {
        isVisible = true
    }

    func animateOnDisappear(completionHandler: (() -> Void)? = nil) {
        isVisible = false
    }

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
        guard isVisible else { return }
        isMouseInsideView = true
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isMouseInsideView = false
    }

    func typingAttributes(for range: Range<Int>) -> [(attributes: [BeamText.Attribute], range: Range<Int>)]? { nil }

    // MARK: - Key Handlers

    func formatterHandlesCursorMovement(direction: CursorMovement,
                                        modifierFlags: NSEvent.ModifierFlags? = nil) -> Bool {
        false
    }

    func formatterHandlesEnter() -> Bool {
        false
    }

    func formatterHandlesInputText(_ text: String) -> Bool {
        false
    }
}

class BaseFormatterViewViewModel {
    @Published var visible: Bool = false
    var animationDirection: Edge = .bottom
}

class FormatterViewViewModel: BaseFormatterViewViewModel, ObservableObject { }
