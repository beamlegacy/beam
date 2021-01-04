//
//  BidirectionalPopoverActionItem.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 31/12/2020.
//

import Cocoa

class BidirectionalPopoverActionItem: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier("BidirectionalPopoverActionItem")

    // MARK: - Properties
    @IBOutlet weak var containerView: NSView!
    @IBOutlet weak var queryLabel: NSTextField!
    @IBOutlet weak var actionLabel: NSTextField!

    private var trackingArea: NSTrackingArea?

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        trackingArea = nil
        containerView.layer?.backgroundColor = .clear
    }

    override var isSelected: Bool {
        didSet {
            containerView.layer?.backgroundColor = isSelected ? NSColor.bidirectionalPopoverBackgroundHoverColor.cgColor : NSColor.clear.cgColor
        }
    }

    // MARK: - UI
    private func setupUI() {
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 5
        queryLabel.textColor = NSColor.bidirectionalPopoverTextColor
        actionLabel.textColor = NSColor.bidirectionalPopoverActionTextColor
    }

    // MARK: - Methods
    func updateLabel(with query: String) {
        queryLabel.stringValue = query
        trackingArea = NSTrackingArea(rect: view.bounds, options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited], owner: self, userInfo: nil)

        guard let trackingArea = trackingArea else { return }
        containerView.addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        containerView.layer?.backgroundColor = NSColor.bidirectionalPopoverBackgroundHoverColor.cgColor
    }

    override func mouseExited(with event: NSEvent) {
        containerView.layer?.backgroundColor = .clear
    }

}
