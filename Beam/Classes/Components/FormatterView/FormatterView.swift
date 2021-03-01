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
    @IBOutlet weak var formatterContainerView: NSView!

    var hyperlinkView: HyperlinkView?
    var didSelectFormatterType: ((_ type: FormatterType, _ isActive: Bool) -> Void)?
    var didPressValidLink: ((_ link: String, _ oldLink: String) -> Void)?
    var didPressDeleteLink: ((_ link: String) -> Void)?

    var urlValue: String = "" {
        didSet {
            updateHyperlinkView()
        }
    }

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

    var idealSize: NSSize {
        let itemSize = CGFloat(items.count)
        let width = (itemSize * 34) + (1.45 * itemSize)
        return NSSize(width: width, height: 32)
    }

    // View Properties
    private let cornerRadius: CGFloat = 6
    private let leading = 2
    private let yPosition = 2
    private let spaceItem = 1
    private let itemWidth = 34
    private let itemHeight = 28

    // Shadow Properties
    private let shadowOpacity: Float = 0.07
    private let shadowRadius: CGFloat = 6
    private let shadowOffset = NSSize(width: 0, height: -1.5)

    private var viewType: FormatterViewType = .persistent
    private var selectedTypes: Set<FormatterType> = []
    private var buttons: [FormatterType: NSButton] = [:]

    // MARK: - Initializer
    convenience init(viewType: FormatterViewType) {
        self.init(frame: CGRect.zero)
        self.viewType = viewType
        drawShadow()
        commonInitUI()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        loadXib()
        drawShadow()
        commonInitUI()
        setupContainerView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        hideHyperLinkView()
    }

    // MARK: - UI
    private func commonInitUI() {
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = corderRadius
        containerView.layer?.borderWidth = 0.7
        containerView.layer?.borderColor = NSColor.formatterBorderColor.cgColor
        containerView.layer?.backgroundColor = viewType == .persistent ?
            NSColor.formatterViewBackgroundColor.cgColor : NSColor.formatterViewBackgroundHoverColor.cgColor

    }

    private func setupContainerView() {
        guard let containerView = containerView else { return }

        let trackingArea = NSTrackingArea(
            rect: containerView.bounds,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: ["view": containerView]
        )

        containerView.addTrackingArea(trackingArea)
    }

    private func drawShadow() {
        self.wantsLayer = true

        self.shadow = NSShadow()
        self.layer?.allowsEdgeAntialiasing = true
        self.layer?.drawsAsynchronously = true
        self.layer?.shadowColor = viewType == .inline ? NSColor.formatterShadowColor.cgColor : NSColor.clear.cgColor
        self.layer?.shadowOpacity = viewType == .inline ? shadowOpacity : 0
        self.layer?.shadowRadius = viewType == .inline ? shadowRadius : 0
        self.layer?.shadowOffset = viewType == .inline ? shadowOffset : NSSize.zero
    }

    private func animateShadowOnMouseEntered(_ isHover: Bool) {
        guard viewType == .persistent else { return }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.allowsImplicitAnimation = true
            ctx.duration = 0.3

            layer?.shadowColor = isHover ? NSColor.formatterShadowColor.cgColor : NSColor.clear.cgColor
            layer?.shadowOpacity = isHover ? shadowOpacity : 0
            layer?.shadowRadius = isHover ? shadowRadius : 0
            layer?.shadowOffset = isHover ? shadowOffset : NSSize.zero
            containerView.layer?.backgroundColor = isHover ? NSColor.formatterViewBackgroundHoverColor.cgColor : NSColor.formatterViewBackgroundColor.cgColor
        }
    }

    private func animateButtonOnMouseEntered(_ button: NSButton, _ isHover: Bool) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.allowsImplicitAnimation = true
            ctx.duration = 0.3

            button.contentTintColor = isHover ? NSColor.formatterIconHoverAndActiveColor : NSColor.formatterIconColor
        }
    }

    // MARK: - Methods

    func setActiveFormmatters(_ types: [FormatterType]) {
        if types.isEmpty {
            selectedTypes = []
            buttons.forEach { button in
                button.value.contentTintColor = NSColor.formatterIconColor
                button.value.layer?.backgroundColor = NSColor.clear.cgColor
            }

            return
        }

        types.forEach { type in
            guard let button = buttons[type] else { return }
            button.contentTintColor = NSColor.formatterIconHoverAndActiveColor
            button.layer?.backgroundColor = NSColor.formatterButtonBackgroudHoverColor.cgColor
            selectedTypes.insert(type)
        }
    }

    func setActiveFormatter(_ type: FormatterType) {
        guard let button = buttons[type] else { return }

        removeState(type)

        if selectedTypes.contains(type) {
            button.contentTintColor = NSColor.formatterIconColor
            button.layer?.backgroundColor = NSColor.clear.cgColor
            selectedTypes.remove(type)
        } else {
            button.contentTintColor = NSColor.formatterIconHoverAndActiveColor
            button.layer?.backgroundColor = NSColor.formatterButtonBackgroudHoverColor.cgColor
            selectedTypes.insert(type)
        }
    }

    func resetSelectedItems() {
        self.selectedTypes = []
        buttons.forEach { button in
            button.value.contentTintColor = NSColor.formatterIconColor
            button.value.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    func showHyperLinkView() {
        hyperlinkView = HyperlinkView(frame: containerView.frame)

        guard let hyperlinkView = hyperlinkView else { return }

        hyperlinkView.didPressValidButton = { [unowned self] link, old in
            guard let didPressValideLink = didPressValidLink else { return }
            didPressValideLink(link, old)
        }

        hyperlinkView.didPressDeleteButton = {[unowned self] link in
            guard let didPressDeleteLink = didPressDeleteLink else { return }
            didPressDeleteLink(link)
        }

        containerView.addSubview(hyperlinkView)
        formatterContainerView.isHidden = true
    }

    func updateHyperlinkView() {
        guard let hyperlinkView = hyperlinkView else { return }
        hyperlinkView.oldUrl = urlValue
        hyperlinkView.hyperlinkTextField.stringValue = urlValue
        hyperlinkView.setupActionButtons()
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
        let isActive = selectedTypes.contains(type)

        if type == FormatterType.link && !isActive {
            showHyperLinkView()
        }

        if !selectedTypes.contains(type) { selectedTypes.insert(type) }

        removeState(type)

        if isActive {
            guard let button = buttons[type] else { return }

            button.contentTintColor = NSColor.formatterIconColor
            button.layer?.backgroundColor = NSColor.clear.cgColor
            selectedTypes.remove(type)
        }

        didSelectFormatterType(type, isActive)
    }

    private func loadItems() {
        items.enumerated().forEach { (index, item) in
            let xPosition = index == 0 ? leading : (itemWidth * index) + (spaceItem * index) + leading
            let button = FormatterTypeButton(frame: NSRect(x: xPosition, y: yPosition, width: itemWidth, height: itemHeight))
            let trackingButtonArea = NSTrackingArea(
                rect: button.bounds,
                options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
                owner: self,
                userInfo: ["view": button, "item": item]
            )

            button.layer?.cornerRadius = cornerRadius
            button.contentTintColor = NSColor.formatterIconColor
            button.image = NSImage(named: "editor-format_\(item)")
            button.tag = index
            button.target = self
            button.action = #selector(selectItemAction(_:))
            button.addTrackingArea(trackingButtonArea)

            buttons[item] = button
            formatterContainerView.addSubview(button)
        }
    }

    private func updateFormatterView(with userInfo: [ AnyHashable: Any ], isHover: Bool) {
        guard let view = userInfo["view"] as? NSView else { return }

        if view == containerView {
            DispatchQueue.main.async {[weak self] in
                guard let self = self else { return }
                self.animateShadowOnMouseEntered(isHover)
            }
        } else {
            guard let type = userInfo["item"] as? FormatterType,
                  let button = buttons[type] else { return }

            DispatchQueue.main.async {[weak self] in
                guard let self = self else { return }
                if !self.selectedTypes.contains(type) { self.animateButtonOnMouseEntered(button, isHover) }
            }
        }
    }

    private func removeState(_ type: FormatterType) {
        if type == .h2 && selectedTypes.contains(.h1) ||
           type == .quote && selectedTypes.contains(.h1) ||
           type == .code && selectedTypes.contains(.h1) { removeActiveIndicator(to: .h1) }

        if type == .h1 && selectedTypes.contains(.h2) ||
           type == .quote && selectedTypes.contains(.h2) ||
           type == .code && selectedTypes.contains(.h2) { removeActiveIndicator(to: .h2) }

        if type == .h2 && selectedTypes.contains(.quote) ||
           type == .h1 && selectedTypes.contains(.quote) { removeActiveIndicator(to: .quote) }

        if type == .h2 && selectedTypes.contains(.code) ||
           type == .h1 && selectedTypes.contains(.code) { removeActiveIndicator(to: .code) }
    }

    private func removeActiveIndicator(to item: FormatterType) {
        guard let button = buttons[item] else { return }
        button.contentTintColor = NSColor.formatterIconColor
        button.layer?.backgroundColor = NSColor.clear.cgColor
        selectedTypes.remove(item)
    }

    private func hideHyperLinkView() {
        hyperlinkView?.removeFromSuperview()
        hyperlinkView = nil
        selectedTypes.remove(FormatterType.link)
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
