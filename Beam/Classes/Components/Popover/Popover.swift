//
//  Popover.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 22/12/2020.
//

import Cocoa

protocol PopoverDelegate: class {
    func didSelected()
}

class Popover<T>: NSView {

    // MARK: - Properties
    weak var delegate: PopoverDelegate?

    var text: String = "Hello World" {
        didSet {
            updateLabel(text)
        }
    }

    var sources: [T] = [] {
        didSet {
            print(sources)
        }
    }

    private var label: NSTextField?

    // MARK: - Initializer
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 10
        setupLabel()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Setup UI
    private func setupLabel() {
        label = NSTextField()
        label?.stringValue = text
        label?.frame = NSRect(x: 0, y: 0, width: frame.width, height: frame.height)
        self.addSubview(label!)
    }

    // MARK: - Methods
    private func updateLabel(_ text: String) {
        label?.stringValue = text
    }

}
