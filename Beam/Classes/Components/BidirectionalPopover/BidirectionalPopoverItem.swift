//
//  BidirectionalPopoverItem.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 28/12/2020.
//

import Cocoa

class BidirectionalPopoverItem: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier("BidirectionalPopoverItem")

    // MARK: - Properties
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var containerView: NSView!

    var documentTitle: String? {
        didSet {
            guard let documentTitle = documentTitle else { return }
            setupDocument(title: documentTitle)
        }
    }

    private var trackingArea: NSTrackingArea?

    // MARK: Life Cycle
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        trackingArea = nil
        titleLabel.stringValue = ""
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
        titleLabel.textColor = NSColor.bidirectionalPopoverTextColor
    }

    // MARK: - Methods
    override func mouseEntered(with event: NSEvent) {
        containerView.layer?.backgroundColor = NSColor.bidirectionalPopoverBackgroundHoverColor.cgColor
    }

    override func mouseExited(with event: NSEvent) {
        containerView.layer?.backgroundColor = .clear
    }

    private func setupDocument(title: String) {
        titleLabel.stringValue = title
        trackingArea = NSTrackingArea(rect: view.bounds, options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited], owner: self, userInfo: nil)

        guard let trackingArea = trackingArea else { return }
        view.addTrackingArea(trackingArea)
    }
}
