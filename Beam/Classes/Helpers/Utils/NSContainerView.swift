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
                oldValue?.removeFromSuperview()

                if let contentView = self.contentView {
                    self.contentHolder.addSubview(contentView)
                    contentView.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([
                        contentView.leadingAnchor.constraint(equalTo: self.contentHolder.leadingAnchor),
                        contentView.trailingAnchor.constraint(equalTo: self.contentHolder.trailingAnchor),
                        contentView.topAnchor.constraint(equalTo: self.contentHolder.topAnchor),
                        contentView.bottomAnchor.constraint(equalTo: self.contentHolder.bottomAnchor)
                    ])
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
