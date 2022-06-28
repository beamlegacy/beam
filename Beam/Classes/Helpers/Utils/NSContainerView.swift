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
            DispatchQueue.mainSync { self.insertNewContentView(contentView, oldValue: oldValue) }
        }
    }

    private let contentHolder: NSView

    init() {
        contentHolder = NSView()
        super.init(frame: NSRect())
        addSubview(contentHolder)
        contentHolder.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentHolder.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentHolder.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentHolder.topAnchor.constraint(equalTo: topAnchor),
            contentHolder.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    convenience init(contentView: ContentView) {
        self.init()
        self.contentView = contentView
        self.insertNewContentView(contentView, oldValue: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func insertNewContentView(_ contentView: ContentView, oldValue: ContentView?) {
        contentView.autoresizingMask = [.width, .height]
        contentView.frame = contentHolder.bounds
        if let oldValue = oldValue {
            contentHolder.replaceSubview(oldValue, with: contentView)
        } else {
            contentHolder.addSubview(contentView)
        }
    }
}
