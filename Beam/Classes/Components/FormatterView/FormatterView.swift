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
    @IBOutlet weak var collectionView: NSCollectionView!

    var corderRadius: CGFloat = 5 {
        didSet {
            containerView.layer?.cornerRadius = corderRadius
        }
    }

    var items: [FormatterType] = [] {
        didSet {
            collectionView.reloadData()
        }
    }

    private var buttons: [FormatterType: NSButton] = [:]

    // MARK: - Initializer
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        loadXib()
        drawShadow()
        setupUI()
        setupCollectionView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        print("deinit")
    }

    // MARK: - UI
    private func setupUI() {
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.formatterViewBackgroundColor.cgColor
        containerView.layer?.cornerRadius = corderRadius
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = NSColor.formatterBorderColor.cgColor
    }

    private func setupCollectionView() {
        let trackingArea = NSTrackingArea(rect: collectionView.bounds, options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited], owner: self, userInfo: nil)
        let layout = NSCollectionViewFlowLayout()
        layout.scrollDirection = .horizontal

        collectionView.register(FormatterViewItem.self, forItemWithIdentifier: FormatterViewItem.identifier)
        collectionView.addTrackingArea(trackingArea)

        collectionView.delegate = self
        collectionView.dataSource = self

        collectionView.isSelectable = true
        collectionView.wantsLayer = true
        collectionView.collectionViewLayout = layout
        collectionView.backgroundColors = [.clear]
        collectionView.layer?.backgroundColor = .clear
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
            layer?.shadowOpacity = isHover ? 0.25 : 0
            layer?.shadowRadius = isHover ? 2 : 0
            layer?.shadowOffset.height = isHover ? -1.5 : 0
        }
    }

    private func animateButtonOnMouseEntered(_ button: NSButton, isHover: Bool) {
        NSAnimationContext.runAnimationGroup { (ctx) in
            ctx.allowsImplicitAnimation = true
            ctx.duration = 0.3

            button.layer?.backgroundColor = isHover ? NSColor.formatterButtonBackgroudHoverColor.cgColor : NSColor.clear.cgColor
        }
    }

    // MARK: - Methods
    override func mouseEntered(with event: NSEvent) {
        DispatchQueue.main.async {[weak self] in
            guard let self = self else { return }
            self.animateShadowOnMouseEntered(true)
        }
    }

    override func mouseExited(with event: NSEvent) {
        DispatchQueue.main.async {[weak self] in
            guard let self = self else { return }
            self.animateShadowOnMouseEntered(false)
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

extension FormatterView: NSCollectionViewDataSource {

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: FormatterViewItem.identifier, for: indexPath)

        guard let formatterViewItem = item as? FormatterViewItem else { return item }
        formatterViewItem.setupItem(items[indexPath.item])

        return formatterViewItem
    }

}

extension FormatterView: NSCollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        return NSSize(width: 20, height: 20)
    }

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, insetForSectionAt section: Int) -> NSEdgeInsets {
        return NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
    }

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 13
    }

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }

}

extension FormatterView: NSCollectionViewDelegate {

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }
        print(items[indexPath.item])
    }

}
