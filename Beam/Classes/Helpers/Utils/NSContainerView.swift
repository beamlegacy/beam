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
            guard oldValue !== contentView else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if let contentView = self.contentView {
                    // We are using autoresizingMask instead of autolayout to support embedded devtools (developerExtrasEnabled)
                    // see: https://stackoverflow.com/q/60727065
                    contentView.autoresizingMask = [.width, .height]
                    contentView.frame = self.contentHolder.bounds
                    if let oldValue = oldValue {
                        self.contentHolder.replaceSubview(oldValue, with: contentView)
                    } else {
                        self.contentHolder.addSubview(contentView)
                    }
                }
            }
        }
    }

    private var contentHolder: NSView

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

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
