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
    @IBOutlet weak var queryLabel: NSTextField!
    @IBOutlet weak var actionLabel: NSTextField!

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    // MARK: - UI
    private func setupUI() {
        queryLabel.textColor = NSColor.bidirectionalPopoverTextColor
        actionLabel.textColor = NSColor.bidirectionalPopoverTextColor
    }
}
