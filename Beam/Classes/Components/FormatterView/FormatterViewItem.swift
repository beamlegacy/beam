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

    private var trackingArea: NSTrackingArea?

    // MARK: Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.cornerRadius = 3
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        trackingArea = nil
        formatterItemIcon.image = nil
    }

    // MARK: - Methods
    func setupItem(_ item: FormatterType) {
        formatterItemIcon.image = NSImage(named: "editor-format_\(item)")
        trackingArea = NSTrackingArea(rect: view.bounds, options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited], owner: self, userInfo: nil)

        guard let trackingArea = trackingArea else { return }
        view.addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        view.layer?.backgroundColor = NSColor.formatterButtonBackgroudHoverColor.cgColor
    }

    override func mouseExited(with event: NSEvent) {
        view.layer?.backgroundColor = .clear
    }

}
