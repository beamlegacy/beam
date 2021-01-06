//
//  BidirectionalPopoverResultItem.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 28/12/2020.
//

import Cocoa

class BidirectionalPopoverResultItem: BidirectionalPopoverItem {

    static let identifier = NSUserInterfaceItemIdentifier("BidirectionalPopoverResultItem")

    // MARK: - Properties
    @IBOutlet weak var titleLabel: NSTextField!

    var documentTitle: String? {
        didSet {
            guard let documentTitle = documentTitle else { return }
            setupDocument(title: documentTitle)
        }
    }

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

    // MARK: - UI
    private func setupUI() {
        titleLabel.textColor = NSColor.bidirectionalPopoverTextColor
    }

    // MARK: - Methods
    private func setupDocument(title: String) {
        titleLabel.stringValue = title
        trackingArea = NSTrackingArea(rect: view.bounds, options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited], owner: self, userInfo: nil)

        guard let trackingArea = trackingArea else { return }
        containerView.addTrackingArea(trackingArea)
    }
}
