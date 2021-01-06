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
    @IBOutlet weak var stackView: NSStackView!

    var didSelectFormatterType: ((_ type: FormatterType, _ isActive: Bool) -> Void)?

    var corderRadius: CGFloat = 5 {
        didSet {
            containerView.layer?.cornerRadius = corderRadius
        }
    }

    var items: [FormatterType] = [] {
        didSet {
            loadItems()
        }
    }

    private var selectedItem = FormatterType.unknow
    private var buttons: [FormatterType: NSButton] = [:]

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
        containerView.layer?.borderWidth = 0.5
        containerView.layer?.borderColor = NSColor.formatterBorderColor.cgColor
    }

    private func setupStackView() {
        let trackingArea = NSTrackingArea(
            rect: stackView.bounds,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: ["view": stackView!]
        )

        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.distribution = .fillProportionally
        stackView.spacing = 13
        stackView.addTrackingArea(trackingArea)
    }

    private func drawShadow() {
        self.wantsLayer = true

        self.shadow = NSShadow()
        self.layer?.allowsEdgeAntialiasing = true
        self.layer?.drawsAsynchronously = true
        self.layer?.shadowColor = NSColor.formatterShadowColor.cgColor
        self.layer?.shadowOpacity = 0
        self.layer?.shadowRadius = 0
        self.layer?.shadowOffset = NSSize(width: 0, height: 0)
    }

    private func animateShadowOnMouseEntered(_ isHover: Bool) {
        NSAnimationContext.runAnimationGroup { (ctx) in
            ctx.allowsImplicitAnimation = true
            ctx.duration = 0.3

            containerView.layer?.backgroundColor = isHover ? NSColor.formatterViewBackgroundHoverColor.cgColor : NSColor.formatterViewBackgroundColor.cgColor
            layer?.shadowOpacity = isHover ? 0.07 : 0
            layer?.shadowRadius = isHover ? 3 : 0
            layer?.shadowOffset.height = isHover ? -1.5 : 0
        }
    }

    private func animateButtonOnMouseEntered(_ button: NSButton, _ isHover: Bool) {
        NSAnimationContext.runAnimationGroup { (ctx) in
            ctx.allowsImplicitAnimation = true
            ctx.duration = 0.3

            button.layer?.backgroundColor = isHover ? NSColor.formatterButtonBackgroudHoverColor.cgColor : NSColor.clear.cgColor
        }
    }

    // MARK: - Methods
    override func mouseEntered(with event: NSEvent) {
        guard let userInfo = event.trackingArea?.userInfo else { return }
        updateFormatterView(with: userInfo, isHover: true)
    }

    override func mouseExited(with event: NSEvent) {
        guard let userInfo = event.trackingArea?.userInfo else { return }
        updateFormatterView(with: userInfo, isHover: false)
    }

    @objc
    private func selectItemAction(_ sender: NSButton) {
        guard let didSelectFormatterType = didSelectFormatterType else { return }
        let item = items[sender.tag]
        let isActive = selectedItem == item

        if isActive {
            guard let button = buttons[selectedItem] else { return }
            selectedItem = .unknow

            button.contentTintColor = NSColor.formatterIconColor
            button.layer?.backgroundColor = NSColor.clear.cgColor
            didSelectFormatterType(item, isActive)
            return
        }

        didSelectFormatterType(item, isActive)

        if selectedItem != .unknow {
            guard let button = buttons[selectedItem] else { return }
            button.contentTintColor = NSColor.formatterIconColor
            button.layer?.backgroundColor = NSColor.clear.cgColor

            selectedItem = item

            guard let buttonSelected = buttons[item] else { return }
            buttonSelected.contentTintColor = NSColor.formatterActiveIconColor
            buttonSelected.layer?.backgroundColor = NSColor.formatterButtonBackgroudHoverColor.cgColor
        }

        if selectedItem == .unknow {
            guard let button = buttons[item] else { return }
            selectedItem = item

            button.contentTintColor = NSColor.formatterActiveIconColor
            button.layer?.backgroundColor = NSColor.formatterButtonBackgroudHoverColor.cgColor
        }
    }

    private func loadItems() {
        items.enumerated().forEach { (index, item) in
            let button = FormatterTypeButton()
            let trackingButtonArea = NSTrackingArea(
                rect: button.bounds,
                options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
                owner: self,
                userInfo: ["view": button, "item": item]
            )

            button.layer?.cornerRadius = 3
            button.contentTintColor = NSColor.formatterIconColor
            button.image = NSImage(named: "editor-format_\(item)")
            button.tag = index
            button.target = self
            button.action = #selector(selectItemAction(_:))
            button.addTrackingArea(trackingButtonArea)

            buttons[item] = button
            stackView.addArrangedSubview(button)
        }
    }

    private func updateFormatterView(with userInfo: [ AnyHashable: Any ], isHover: Bool) {
        guard let view = userInfo["view"] as? NSView else { return }

        if view == stackView {
            DispatchQueue.main.async {[weak self] in
                guard let self = self else { return }
                self.animateShadowOnMouseEntered(isHover)
            }
        } else {
            guard let item = userInfo["item"] as? FormatterType,
                  let button = buttons[item] else { return }

            DispatchQueue.main.async {[weak self] in
                guard let self = self else { return }
                if self.selectedItem != item { self.animateButtonOnMouseEntered(button, isHover) }
            }
        }
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
