//
//  LinkView.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 12/02/2021.
//

import Cocoa

class LinkView: NSView {

    @IBOutlet var containerView: NSView!

    var didPressButton: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        loadXib()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        print("deinit linkview")
    }

    @IBAction func dismissAction(_ sender: Any) {
        didPressButton!()
    }

    private func loadXib() {
        let bundle = Bundle(for: type(of: self))
        guard let nib = NSNib(nibNamed: nibName, bundle: bundle) else { fatalError("Impossible to load \(nibName)") }
        _ = nib.instantiate(withOwner: self, topLevelObjects: nil)

        containerView.frame = bounds
        containerView.autoresizingMask = [.width, .height]
        addSubview(containerView)
    }
}
