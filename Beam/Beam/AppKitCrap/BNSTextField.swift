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

class BNSTextField : NSTextView, ObservableObject, NSTextViewDelegate {
    var value: Binding<String> = .constant("")
    public var onEditingChanged: (Bool) -> Void = { _ in }
    public var inSelectionUpdate: Bool = false
    public var isEditing = false {
        didSet {
            onEditingChanged(isEditing)
        }
    }
    public var onTextChanged: (String) -> Void = { _ in }
    public var onCommit: () -> Void = { }
    public var onPerformKeyEquivalent: (NSEvent) -> Bool = { _ in return false }
    public var focusOnCreation: Bool = false

    override public init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
    }

    public init(string stringValue: Binding<String>, focusOnCreation: Bool = false) {
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
    
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
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
        onTextChanged(self.string)
        value.wrappedValue = self.string
    }

//    public func textViewDidChangeSelection(_ notification: Notification) {
//        if !inSelectionUpdate {
//            selectionRanges.wrappedValue = selectedRanges.map({ value -> Range<Int> in
//                value.rangeValue.lowerBound ..< value.rangeValue.upperBound
//            })
//        }
//    }
//
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


    override func viewDidMoveToWindow() {
        if focusOnCreation {
            //self.window?.initialFirstResponder = self
            DispatchQueue.main.async {
                self.window?.makeFirstResponder(self)
            }
        }
    }
    
    @objc func commit(_ sender: AnyObject) {
        onCommit()
    }
    
    public var placeholderText: String? = nil
    public var placeholderTextColor: NSColor = NSColor.lightGray

    private var placeholderInsets = NSEdgeInsets(top: 0.0, left: 4.0, bottom: 0.0, right: 4.0)

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard string.isEmpty else { return }
        if let s = placeholderText {
            let attribs = [NSAttributedString.Key.font: font!, .foregroundColor: placeholderTextColor]
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


