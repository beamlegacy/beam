//
//  BidirectionalPopoverItem.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 28/12/2020.
//

import Cocoa

class BidirectionalPopoverItem: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier("BidirectionalPopoverItem")

    @IBOutlet weak var titleLabel: NSTextField!

    var document: DocumentStruct? {
        didSet {
            guard let document = document else { return }
            titleLabel.stringValue = document.title
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
    }

}
