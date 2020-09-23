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
        self.target = self
        self.action = #selector(commit)
        self.isEditable = true
        self.isSelectable = true
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
        return super.becomeFirstResponder()
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
        if onPerformKeyEquivalent(event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func viewDidMoveToWindow() {
        if focusOnCreation {
            self.window?.makeFirstResponder(self)
        }
    }
    
    @objc func commit(_ sender: AnyObject) {
        onCommit()
    }
    
    public override var acceptsFirstResponder: Bool {
        return true
    }
}


