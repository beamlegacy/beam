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
        isEditing = true
        super.edit(withFrame: titleRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, event: event)
    }
    
    
    
    override func select(withFrame aRect: NSRect, in controlView: NSView, editor textObj: NSText, delegate anObject: Any?, start selStart: Int, length selLength: Int) {
        super.select(withFrame: titleRect(forBounds: aRect), in: controlView, editor: textObj, delegate: anObject, start: selStart, length: selLength)
    }
    
    override func endEditing(_ textObj: NSText) {
        super.endEditing(textObj)
        isEditing = false
    }
    
    var isEditing = false
}


class BNSTextField : NSTextView, ObservableObject, NSTextViewDelegate {
    var value: Binding<String> = .constant("")
    var selectionRange: Binding<Range<Int>> = .constant(0..<0)
    public var onEditingChanged: (Bool) -> Void = { _ in }
    public var isEditing = false {
        didSet {
            onEditingChanged(isEditing)
        }
    }
    public var onCommit: () -> Void = { }
    public var onPerformKeyEquivalent: (NSEvent) -> Bool = { _ in return false }
    public var focusOnCreation: Bool = false

    override public init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
    }

    public init(string stringValue: Binding<String>, focusOnCreation: Bool = false, selectionRange: Binding<Range<Int>>) {
        self.selectionRange = selectionRange
        self.focusOnCreation = focusOnCreation
        super.init(frame: NSRect())
        self.value = stringValue
        self.isEditable = true
        self.isSelectable = true
        self.string = value.wrappedValue
        self.font = NSFont.systemFont(ofSize: 16)
        self.backgroundColor = NSColor(named: "transparent")!
        self.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func becomeFirstResponder() -> Bool {
        needsDisplay = true
        isEditing = true
        return true
    }
    
    public override func resignFirstResponder() -> Bool {
        isEditing = false
        return super.resignFirstResponder()
    }

    public func textDidChange(_ notification: Notification) {
        value.wrappedValue = self.string
    }

    override func insertNewline(_ sender: Any?) {
        onCommit()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isEditing  {
            if onPerformKeyEquivalent(event) {
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }


//    override func viewDidMoveToWindow() {
//        if focusOnCreation {
//            //self.window?.initialFirstResponder = self
//            DispatchQueue.main.async {
//                self.window?.makeFirstResponder(self)
//            }
//        }
//    }
    
    @objc func commit(_ sender: AnyObject) {
        onCommit()
    }
    
    public override var intrinsicContentSize: NSSize {
        var i = super.intrinsicContentSize
        i.height = 21
        return i
    }

    public var placeholderString: String? = nil
    private var placeholderInsets = NSEdgeInsets(top: 0.0, left: 4.0, bottom: 0.0, right: 4.0)

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard string.isEmpty else { return }
        if let s = placeholderString {
            let attribs = [NSAttributedString.Key.font: font!, .foregroundColor: NSColor(named: "PlaceholderTextColor")]
            NSAttributedString(string: s, attributes: attribs as [NSAttributedString.Key : Any]).draw(in: dirtyRect.insetBy(placeholderInsets))
        }
    }
}

extension NSRect {
    func insetBy(_ insets: NSEdgeInsets) -> NSRect {
        return insetBy(dx: insets.left + insets.right, dy: insets.top + insets.bottom)
        .applying(CGAffineTransform(translationX: insets.left - insets.right, y: insets.top - insets.bottom))
    }
}


