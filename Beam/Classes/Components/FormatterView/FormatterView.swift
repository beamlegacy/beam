//
//  FormatterView.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 03/01/2021.
//

import Cocoa

class FormatterView: NSView {

    // MARK: - Properties
    @IBOutlet var containerView: NSView!
    @IBOutlet weak var formatterStackView: NSStackView!

    var corderRadius: CGFloat = 5 {
        didSet {
            containerView.layer?.cornerRadius = corderRadius
        }
    }

    var items: [FormatterType] = [] {
        didSet {
            addItemToStackView()
        }
    }

    private var t: [FormatterType : NSButton] = [:]

    // MARK: - Initializer
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        loadXib()
        drawShadow()
        setupUI()
        setupStackView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - UI
    private func setupUI() {
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.formatterViewBackgroundColor.cgColor
        containerView.layer?.cornerRadius = corderRadius
    }

    private func setupStackView() {
        formatterStackView.orientation = .horizontal
        formatterStackView.alignment = .centerY
        formatterStackView.distribution = .fillEqually
        formatterStackView.spacing = 0

        let trackingArea = NSTrackingArea(rect: formatterStackView.bounds, options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited], owner: self, userInfo: ["view": formatterStackView!])
        formatterStackView.addTrackingArea(trackingArea)
    }

    private func drawShadow() {
        self.wantsLayer = true

        self.shadow = NSShadow()
        self.layer?.allowsEdgeAntialiasing = true
        self.layer?.drawsAsynchronously = true
        self.layer?.shadowColor = NSColor.formatterShadowColor.cgColor
        self.layer?.shadowOpacity = 1
        self.layer?.shadowRadius = 0.45
        self.layer?.shadowOffset = NSSize(width: 0, height: 0)
    }

    // MARK: - Methods
    override func mouseEntered(with event: NSEvent) {
        guard let userInfo = event.trackingArea?.userInfo,
              let view = userInfo["view"] as? NSView else { return }

        if view == formatterStackView {
            DispatchQueue.main.async {[weak self] in
                guard let self = self else { return }

                NSAnimationContext.runAnimationGroup { (ctx) in
                    ctx.allowsImplicitAnimation = true
                    ctx.duration = 0.3

                    self.layer?.shadowOpacity = 0.5
                    self.layer?.shadowRadius = 2
                    self.layer?.shadowOffset.height = -2
                }
            }
        } else {
            guard let item = userInfo["item"] as? FormatterType else { return }

            DispatchQueue.main.async {[weak self] in
                guard let self = self else { return }

                NSAnimationContext.runAnimationGroup { (ctx) in
                    ctx.allowsImplicitAnimation = true
                    ctx.duration = 0.3

                    self.t[item]?.layer?.backgroundColor = NSColor.red.cgColor
                }
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        guard let userInfo = event.trackingArea?.userInfo,
              let view = userInfo["view"] as? NSView else { return }

        if view == formatterStackView {
            DispatchQueue.main.async {[weak self] in
                guard let self = self else { return }

                NSAnimationContext.runAnimationGroup { (ctx) in
                    ctx.allowsImplicitAnimation = true
                    ctx.duration = 0.3

                    self.layer?.shadowOpacity = 1
                    self.layer?.shadowRadius = 0.45
                    self.layer?.shadowOffset.height = 0
                }
            }
        } else {
            guard let item = userInfo["item"] as? FormatterType else { return }

            DispatchQueue.main.async {[weak self] in
                guard let self = self else { return }

                NSAnimationContext.runAnimationGroup { (ctx) in
                    ctx.allowsImplicitAnimation = true
                    ctx.duration = 0.3

                    self.t[item]?.layer?.backgroundColor = NSColor.clear.cgColor
                }
            }
        }
    }

    private func addItemToStackView() {
        items.forEach({ item in
            let button = NSButton()
            let image = NSImage(named: "editor-format_\(item)")
            let trackingButtonArea = NSTrackingArea(rect: button.bounds, options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited], owner: self, userInfo: ["view": button, "item": item])

            button.wantsLayer = true
            button.isBordered = false
            button.layer?.cornerRadius = 3
            button.contentTintColor = NSColor.formatterIconColor
            button.image = image
            button.addTrackingArea(trackingButtonArea)

            t[item] = button

            formatterStackView.addArrangedSubview(button)
        })
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
