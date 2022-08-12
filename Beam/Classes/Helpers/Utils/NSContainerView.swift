//
//  NSContainerView.swift
//  Beam
//
//  Created by Sebastien Metrot on 20/09/2020.
//

import Foundation
import AppKit

/// A NSView which simply adds some view to its view hierarchy
public class NSViewContainerView<ContentView: NSView>: NSView {
    var contentView: ContentView? {
        didSet {
            guard oldValue !== contentView, let contentView = contentView else { return }
            insertNewContentView(contentView, oldValue: oldValue)
        }
    }

    init(contentView: ContentView?) {
        self.contentView = contentView
        super.init(frame: NSRect())
        if let contentView = contentView {
            self.insertNewContentView(contentView, oldValue: nil)
        }
    }

    convenience init() {
        self.init(contentView: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func insertNewContentView(_ contentView: ContentView, oldValue: ContentView?) {
        contentView.autoresizingMask = [.width, .height]
        contentView.frame = bounds
        if let oldValue = oldValue {
            replaceSubview(oldValue, with: contentView)
        } else {
            addSubview(contentView)
        }
    }
}
