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
class FormatterView: NSView, PopoverWindowContentView {

    static let appearAnimationDuration = 0.3
    static let disappearAnimationDuration = 0.15

    internal var key: String = ""

    var idealSize: CGSize {
        return .zero
    }

    var extraPadding: CGSize {
        return .zero
    }

    var handlesTyping: Bool {
        false
    }

    var shouldDebouncePresenting: Bool {
        false
    }

    var isMouseInsideView = false
    private(set) var isVisible = false
    init(key: String) {
        super.init(frame: .zero)
        self.key = key
        self.setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func didClose() {
    }

    func setupUI() {
        self.wantsLayer = true
    }

    func animateOnAppear(completionHandler: (() -> Void)? = nil) {
        isVisible = true
        if shouldDebouncePresenting {
            self.window?.makeKeyAndOrderFront(nil)
        }
        completionHandler?()
    }

    func animateOnDisappear(completionHandler: (() -> Void)? = nil) {
        isVisible = false
        completionHandler?()
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

    // MARK: - PopoverWindow handling
    func popoverWindowDidClose() {
        didClose()
    }

    func popoverWindowShouldAutoClose(validationBlock: @escaping (Bool) -> Void) {
        animateOnDisappear {
            validationBlock(true)
        }
    }
}

class BaseFormatterViewViewModel {
    @Published var visible: Bool = false
    var animationDirection: Edge = .bottom
}

class FormatterViewViewModel: BaseFormatterViewViewModel, ObservableObject { }
