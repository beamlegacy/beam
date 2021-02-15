//
//  HyperlinkView.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 12/02/2021.
//

import Cocoa

class HyperlinkView: NSView {

    // MARK: - Properties
    @IBOutlet var containerView: NSView!
    @IBOutlet weak var hyperlinkTextField: NSTextField!

    var didPressValideButton: (() -> Void)?
    var didPressDeleteButton: (() -> Void)?

    // MARK: - Initializer
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        loadXib()
        setupTextField()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        print("deinit linkview")
    }

    // MARK: - Life Cycle
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.hyperlinkTextField.becomeFirstResponder()
        }
    }

    // MARK: - Private Methods
    private func setupTextField() {
        hyperlinkTextField.wantsLayer = true
        hyperlinkTextField.isBordered = false
        hyperlinkTextField.drawsBackground = false
        hyperlinkTextField.focusRingType = .none

        hyperlinkTextField.placeholderString = "Link’s URL"
        hyperlinkTextField.maximumNumberOfLines = 2
    }

    private func loadXib() {
        let bundle = Bundle(for: type(of: self))
        guard let nib = NSNib(nibNamed: nibName, bundle: bundle) else { fatalError("Impossible to load \(nibName)") }
        _ = nib.instantiate(withOwner: self, topLevelObjects: nil)

        containerView.frame = bounds
        containerView.autoresizingMask = [.width, .height]
        addSubview(containerView)
    }

    // MARK: - Action
    @IBAction func dismissAction(_ sender: Any) {
        guard let didPressValideButton = didPressValideButton else { return }
        didPressValideButton()
    }
}
