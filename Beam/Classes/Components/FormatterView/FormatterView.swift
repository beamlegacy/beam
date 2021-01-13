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

    private var selectedTypes: [FormatterType: FormatterType] = [:]
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
        stackView.spacing = 6
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
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.allowsImplicitAnimation = true
            ctx.duration = 0.3

            containerView.layer?.backgroundColor = isHover ? NSColor.formatterViewBackgroundHoverColor.cgColor : NSColor.formatterViewBackgroundColor.cgColor
            layer?.shadowOpacity = isHover ? 0.07 : 0
            layer?.shadowRadius = isHover ? 3 : 0
            layer?.shadowOffset.height = isHover ? -1.5 : 0
        }
    }

    private func animateButtonOnMouseEntered(_ button: NSButton, _ isHover: Bool) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.allowsImplicitAnimation = true
            ctx.duration = 0.3

            button.layer?.backgroundColor = isHover ? NSColor.formatterButtonBackgroudHoverColor.cgColor : NSColor.clear.cgColor
        }
    }

    // MARK: - Methods

    func setActiveFormmatters(_ types: [FormatterType]) {
        if types.isEmpty {
            selectedTypes = [:]
            buttons.forEach { button in
                button.value.layer?.backgroundColor = NSColor.clear.cgColor
            }

            return
        }

        types.forEach { type in
            guard let button = buttons[type] else { return }
            button.layer?.backgroundColor = NSColor.formatterButtonBackgroudHoverColor.cgColor
            selectedTypes[type] = type
        }
    }

    func setActiveFormatter(_ type: FormatterType) {
        guard let button = buttons[type] else { return }

        enableCorrectType(type)

        if selectedTypes[type] == type {
            button.layer?.backgroundColor = NSColor.clear.cgColor
            selectedTypes[type] = nil
        } else {
            button.layer?.backgroundColor = NSColor.formatterButtonBackgroudHoverColor.cgColor
            selectedTypes[type] = type
        }
    }

    func resetSelectedItems() {
        self.selectedTypes = [:]
        buttons.forEach { button in
            button.value.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

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
        let type = items[sender.tag]
        let isActive = selectedTypes[type] == type

        if selectedTypes[type] != type { selectedTypes[type] = type }

        enableCorrectType(type)

        if isActive {
            guard let button = buttons[type] else { return }

            button.contentTintColor = NSColor.formatterIconColor
            button.layer?.backgroundColor = NSColor.clear.cgColor
            selectedTypes[type] = nil
        }

        didSelectFormatterType(type, isActive)
    }

    private func loadItems() {
        items.enumerated().forEach { (index, item) in
            let button = FormatterTypeButton(frame: NSRect(x: 0, y: 0, width: 38, height: 28))
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
            guard let type = userInfo["item"] as? FormatterType,
                  let button = buttons[type] else { return }

            DispatchQueue.main.async {[weak self] in
                guard let self = self else { return }
                if self.selectedTypes[type] != type { self.animateButtonOnMouseEntered(button, isHover) }
            }
        }
    }

    private func enableCorrectType(_ type: FormatterType) {
        if type == .h2 && selectedTypes[.h1] == .h1 ||
            type == .quote && selectedTypes[.h1] == .h1 { removeActiveState(to: .h1) }

        if type == .h1 && selectedTypes[.h2] == .h2 ||
            type == .quote && selectedTypes[.h2] == .h2 { removeActiveState(to: .h2) }

        if type == .h2 && selectedTypes[.quote] == .quote ||
            type == .h1 && selectedTypes[.quote] == .quote { removeActiveState(to: .quote) }
    }

    private func removeActiveState(to item: FormatterType) {
        guard let button = buttons[item] else { return }
        button.layer?.backgroundColor = NSColor.clear.cgColor
        selectedTypes[item] = nil
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
