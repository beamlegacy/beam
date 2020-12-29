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

    var document: DocumentStruct? {
        didSet {
            guard let document = document else { return }
            setupDocument(document)
        }
    }

    // MARK: Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        titleLabel.stringValue = ""
    }

    override var isSelected: Bool {
        didSet {
            view.layer?.backgroundColor = isSelected ? NSColor.green.cgColor : NSColor.clear.cgColor
        }
    }

    // MARK: - UI
    private func setupUI() {
        titleLabel.textColor = NSColor.black
    }

    // MARK: - Methods
    private func setupDocument(_ document: DocumentStruct) {
        titleLabel.stringValue = document.title
    }
}
