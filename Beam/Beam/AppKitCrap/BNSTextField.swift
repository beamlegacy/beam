//
//  BNSTextField.swift
//  Beam
//
//  Created by Sebastien Metrot on 20/09/2020.
//

import Foundation
import AppKit
import Combine
import SwiftUI

class VerticallyCenteredTextFieldCell: NSTextFieldCell {
    override func titleRect(forBounds rect: NSRect) -> NSRect {
        var titleRect = super.titleRect(forBounds: rect)

        let minimumHeight = self.cellSize(forBounds: rect).height
        titleRect.origin.y += (titleRect.height - minimumHeight) / 2
        titleRect.size.height = minimumHeight

        return titleRect
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        super.drawInterior(withFrame: titleRect(forBounds: cellFrame), in: controlView)
    }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        super.draw(withFrame: titleRect(forBounds: cellFrame), in: controlView)
    }

    override func highlight(_ flag: Bool, withFrame cellFrame: NSRect, in controlView: NSView) {
        super.highlight(flag, withFrame: titleRect(forBounds: cellFrame), in: controlView)
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: titleRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, event: event)
    }



    override func select(withFrame aRect: NSRect, in controlView: NSView, editor textObj: NSText, delegate anObject: Any?, start selStart: Int, length selLength: Int) {
        super.select(withFrame: titleRect(forBounds: aRect), in: controlView, editor: textObj, delegate: anObject, start: selStart, length: selLength)
    }
}


class BNSTextField : NSTextField, ObservableObject {
    var value: Binding<String>
    public var onEditingChanged: (Bool) -> Void = { _ in }
    public var onCommit: () -> Void = { }
    public var onPerformKeyEquivalent: (NSEvent) -> Bool = { _ in return false }
    public var focusOnCreation: Bool

    public init(string stringValue: Binding<String>, focusOnCreation: Bool = false) {
        value = stringValue
        self.focusOnCreation = focusOnCreation
        super.init(frame: NSRect())
        self.cell = VerticallyCenteredTextFieldCell()
        self.target = self
        self.action = #selector(commit)
        self.isEditable = true
        self.isSelectable = true
        self.usesSingleLineMode = true
        self.stringValue = value.wrappedValue
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func textShouldBeginEditing(_ textObject: NSText) -> Bool {
        return true
    }

    public override func becomeFirstResponder() -> Bool {
        onEditingChanged(true)
        return true
    }
    
    public override func resignFirstResponder() -> Bool {
        onEditingChanged(true)
        return super.resignFirstResponder()
    }
    
    public override func textDidBeginEditing(_ notification: Notification) {
        super.textDidBeginEditing(notification)
    }

    public override func textDidChange(_ notification: Notification) {
        value.wrappedValue = self.stringValue
    }
    
    public override func textShouldEndEditing(_ textObject: NSText) -> Bool {
        return true
    }

    public override func textDidEndEditing(_ notification: Notification) {
//        onEditingChanged(false)
        super.textDidEndEditing(notification)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if window?.firstResponder === self {
            if onPerformKeyEquivalent(event) {
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    @objc func commit(_ sender: AnyObject) {
        onCommit()
    }
    
    public override var acceptsFirstResponder: Bool {
        return true
    }
    
    public override var intrinsicContentSize: NSSize {
        var i = super.intrinsicContentSize
        i.height = 21
        return i
    }
    
}


