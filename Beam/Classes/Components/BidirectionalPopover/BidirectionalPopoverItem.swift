//
//  BidirectionalPopoverItem.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 06/01/2021.
//

import Cocoa

class BidirectionalPopoverItem: NSCollectionViewItem {

    @IBOutlet weak var containerView: NSView!

    var trackingArea: NSTrackingArea?

    override func awakeFromNib() {
        super.awakeFromNib()
        setupContainerUI()
    }

    override var isSelected: Bool {
        didSet {
            containerView.layer?.backgroundColor = isSelected ? NSColor.bidirectionalPopoverBackgroundHoverColor.cgColor : NSColor.clear.cgColor
        }
    }

    // MARK: - UI
    private func setupContainerUI() {
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 5
    }

    // MARK: - Methods
    override func mouseEntered(with event: NSEvent) {
        containerView.layer?.backgroundColor = NSColor.bidirectionalPopoverBackgroundHoverColor.cgColor
    }

    override func mouseExited(with event: NSEvent) {
        containerView.layer?.backgroundColor = isSelected ? NSColor.bidirectionalPopoverBackgroundHoverColor.cgColor : .clear
    }
}
