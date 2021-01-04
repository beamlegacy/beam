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

    override var isSelected: Bool {
        didSet {
            view.layer?.backgroundColor = isSelected ? NSColor.bidirectionalPopoverBackgroundHoverColor.cgColor : NSColor.clear.cgColor
        }
    }

    // MARK: - UI
    private func setupUI() {
        queryLabel.isHidden = true
        actionLabel.isHidden = true

        queryLabel.textColor = NSColor.bidirectionalPopoverTextColor
        actionLabel.textColor = NSColor.bidirectionalPopoverTextColor
    }

    // MARK: - Methods
    func updateLabel(with query: String) {
        queryLabel.isHidden = query.isEmpty ? true : false
        actionLabel.isHidden = query.isEmpty ? true : false

        queryLabel.stringValue = query
    }
}
