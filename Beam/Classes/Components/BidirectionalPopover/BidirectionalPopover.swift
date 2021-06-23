//
//  BidirectionalPopover.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 28/12/2020.
//

import Cocoa

enum PopoverMode {
    case internalLink
    case blockReference
}

protocol PopoverItem {
    var text: String { get }
}

struct PopoverLinkItem: PopoverItem {
    var text: String
}

struct PopoverBlockItem: PopoverItem {
    var text: String
    var noteId: UUID
    var elementId: UUID
}

class BidirectionalPopover: NSView {

    // MARK: - Properties
    @IBOutlet var containerView: NSView!
    @IBOutlet weak var collectionView: BeamCollectionView!

    static let viewWidth: CGFloat = 248
    static let viewHeight: CGFloat = 36

    var mode: PopoverMode
    var initialText: String?

    var didSelectTitle: ((_ title: String) -> Void) = { _ in }
    var didSelectItem: ((_ item: PopoverItem) -> Void) = { _ in }

    var items: [PopoverItem] = [] {
        didSet {
            collectionView.reloadData()

            if items.isEmpty && !isMatchItem {
                resetIndexPath(section: 1)
            } else {
                resetIndexPath(section: 0)
            }
        }
    }

    var query: String = "" {
        didSet {
            checkItemsContainsQuery()
        }
    }

    var idealSize: NSSize {
        var height = Self.viewHeight * CGFloat(items.count) + (query.isEmpty ? 0 : Self.viewHeight)
        if isMatchItem { height -= Self.viewHeight }

        return NSSize(width: Self.viewWidth, height: height)
    }

    private var isMatchItem = false
    private var indexPath = IndexPath(item: 0, section: 0)
    private var collectionViewItems: [NSUserInterfaceItemIdentifier] { [
        mode == .internalLink ? BidirectionalPopoverResultItem.identifier : BidirectionalPopoverBlockItem.identifier,
        BidirectionalPopoverActionItem.identifier
    ]
    }

    // MARK: - Initializer
    init(mode: PopoverMode, initialText: String?) {
        self.mode = mode
        self.initialText = initialText
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 7

        loadXib()
        setupView()
        setupCollectionView()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func draw(_ dirtyRect: NSRect) {
        if let layer = self.layer {
            self.shadow = NSShadow()

            layer.allowsEdgeAntialiasing = true
            layer.drawsAsynchronously = true
            layer.shadowColor = NSColor.black.cgColor
            layer.shadowOpacity = 0.15
            layer.shadowRadius = 3
            layer.shadowOffset = NSSize(width: 0, height: -3)
        }

        super.draw(dirtyRect)
    }

    // MARK: - Life Cycle
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateUI()
    }

    // MARK: - UI
    private func setupView() {
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 7
        containerView.layer?.borderWidth = 1
        updateUI()
    }

    private func updateUI() {
        containerView.layer?.backgroundColor = BeamColor.BidirectionalPopover.background.cgColor
        containerView.layer?.borderColor = BeamColor.BidirectionalPopover.background.cgColor
    }

    private func setupCollectionView() {
        let layout = NSCollectionViewFlowLayout()
        layout.scrollDirection = .vertical

        collectionViewItems.forEach({ item in
            collectionView.register(NSNib(nibNamed: item.rawValue, bundle: nil), forItemWithIdentifier: item)
        })

        collectionView.dataSource = self
        collectionView.delegate = self

        collectionView.isSelectable = true
        collectionView.wantsLayer = true
        collectionView.enclosingScrollView?.borderType = .noBorder
        collectionView.enclosingScrollView?.hasVerticalScroller = false
        collectionView.enclosingScrollView?.automaticallyAdjustsContentInsets = false
        collectionView.backgroundColors = [.clear]
        collectionView.layer?.backgroundColor = .clear
        collectionView.collectionViewLayout = layout
    }

    // MARK: - Methods
    func moveUp() {
        if indexPath.section == 1 {
            collectionView.deselectItems(at: [indexPath])
            indexPath = IndexPath(item: items.count, section: 0)
        }

        guard indexPath.item != 0 else { return }

        collectionView.deselectItems(at: [indexPath])
        collectionView.selectItems(at: [IndexPath(item: indexPath.item - 1, section: indexPath.section)], scrollPosition: .bottom)
        indexPath.item -= 1
    }

    func moveDown() {
        if indexPath.item == items.count - 1 && !isMatchItem && !query.isEmpty {
            guard collectionView.numberOfItems(inSection: 1) > 0 else { return }
            collectionView.deselectItems(at: [indexPath])
            indexPath = IndexPath(item: 0, section: 1)
            collectionView.selectItems(at: [indexPath], scrollPosition: .bottom)
        }

        guard indexPath.section == 0 && indexPath.item != items.count - 1 else { return }

        indexPath.item += 1
        let previousIndexPath = IndexPath(item: indexPath.item - 1, section: indexPath.section)

        collectionView.deselectItems(at: [previousIndexPath])
        collectionView.selectItems(at: [indexPath], scrollPosition: .bottom)
        collectionView.reloadItems(at: [previousIndexPath])
    }

    private func selectFirstItemAt(section: Int = 0) {
        indexPath = IndexPath(item: 0, section: section)
        collectionView.selectItems(at: [indexPath], scrollPosition: .bottom)
    }

    private func resetIndexPath(section: Int = 0) {
        indexPath = IndexPath(item: 0, section: section)
    }

    private func checkItemsContainsQuery() {
        guard !items.isEmpty else {
            isMatchItem = false
            return
        }

        isMatchItem = items.contains(where: {
            query.contains($0.text)
        })

        if isMatchItem {
            selectFirstItemAt(section: 0)
        }
    }

    private func selectDocument(at indexPath: IndexPath) -> String? {
        let itemName = itemNameAt(index: indexPath.section)

        switch itemName {
        case BidirectionalPopoverResultItem.identifier:
            guard let item = collectionView.item(at: IndexPath(item: indexPath.item, section: indexPath.section)) as? BidirectionalPopoverResultItem else { return nil }
            return item.documentTitle
        case BidirectionalPopoverBlockItem.identifier:
            guard let item = collectionView.item(at: IndexPath(item: indexPath.item, section: indexPath.section)) as? BidirectionalPopoverBlockItem else { return nil }
            return item.documentTitle
        case BidirectionalPopoverActionItem.identifier:
            guard let item = collectionView.item(at: IndexPath(item: indexPath.item, section: indexPath.section)) as? BidirectionalPopoverActionItem else { return nil }
            return item.queryLabel.stringValue
        default:
            return nil
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

    private func itemNameAt(index: Int) -> NSUserInterfaceItemIdentifier {
        return collectionViewItems[index]
    }
}

// MARK: - NSCollectionView DataSource
extension BidirectionalPopover: NSCollectionViewDataSource {

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        if mode == .internalLink {
            return collectionViewItems.count
        }
        return collectionViewItems.count - 1
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        let itemName = itemNameAt(index: section)

        switch itemName {
        case BidirectionalPopoverResultItem.identifier:
            return items.count
        case BidirectionalPopoverBlockItem.identifier:
            return items.count
        case BidirectionalPopoverActionItem.identifier:
            guard mode == .internalLink else { return 0 }
            return isMatchItem || query.isEmpty ? 0 : 1
        default:
            return 0
        }
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let itemName = itemNameAt(index: indexPath.section)
        let item = collectionView.makeItem(withIdentifier: itemName, for: indexPath)

        switch item {
        case is BidirectionalPopoverResultItem:
            guard let popoverItem = item as? BidirectionalPopoverResultItem else { return item }
            popoverItem.documentTitle = items[indexPath.item].text
            if indexPath == self.indexPath { popoverItem.isSelected = true }
            return popoverItem

        case is BidirectionalPopoverBlockItem:
            guard let popoverItem = item as? BidirectionalPopoverBlockItem else { return item }
            popoverItem.documentTitle = items[indexPath.item].text
            if indexPath == self.indexPath { popoverItem.isSelected = true }
            return popoverItem

        default:
            guard let popoverActionItem = item as? BidirectionalPopoverActionItem else { return item }
            popoverActionItem.updateLabel(with: query)
            if !query.isEmpty && indexPath == self.indexPath && !isMatchItem { popoverActionItem.isSelected = true }
            return popoverActionItem
        }

    }

}

// MARK: - NSCollectionView FlowLayout
extension BidirectionalPopover: NSCollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        return mode == .internalLink ? NSSize(width: collectionView.bounds.width, height: 36) : NSSize(width: collectionView.bounds.width, height: 80)
    }

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, insetForSectionAt section: Int) -> NSEdgeInsets {
        return NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }

}

// MARK: - NSCollectionView Delegate
extension BidirectionalPopover: NSCollectionViewDelegate {

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }

        switch mode {
        case .internalLink:
            guard let documentTitle = selectDocument(at: indexPath) else { return }
            didSelectTitle(documentTitle)
        case .blockReference:
            guard indexPath.section == 0 else { return }
            didSelectItem(items[indexPath.item])
        }
    }

    func selectItem() {
        collectionView(collectionView, didSelectItemsAt: Set([indexPath]))
    }

}
