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
    }

    override var isSelected: Bool {
        didSet {
            view.layer?.backgroundColor = isSelected ? NSColor.green.cgColor : NSColor.clear.cgColor
        }
    }

    // MARK: - UI
    private func setupUI() {
        titleLabel.textColor = NSColor.bidirectionalPopoverTextColor
    }

    // MARK: - Methods
    override func mouseEntered(with event: NSEvent) {
        view.layer?.backgroundColor = NSColor.green.cgColor
    }

    override func mouseExited(with event: NSEvent) {
        view.layer?.backgroundColor = .clear
    }

    private func setupDocument(title: String) {
        titleLabel.stringValue = title
        trackingArea = NSTrackingArea(rect: view.bounds, options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited], owner: self, userInfo: nil)

        guard let trackingArea = trackingArea else { return }
        view.addTrackingArea(trackingArea)
    }
}
