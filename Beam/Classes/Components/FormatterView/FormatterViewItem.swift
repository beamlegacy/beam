//
//  FormatterViewItem.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 04/01/2021.
//

import Cocoa

class FormatterViewItem: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier("FormatterViewItem")

    @IBOutlet weak var formatterItemIcon: NSImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.red.cgColor
    }

    func setupItem(_ item: FormatterType) {
        formatterItemIcon.image = NSImage(named: "editor-format_\(item)")
    }

}
