//
//  BidirectionalPopover.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 28/12/2020.
//

import Cocoa

class BidirectionalPopover: Popover {

    // MARK: - Properties
    @IBOutlet var containerView: NSView!
    @IBOutlet weak var collectionView: NSCollectionView!

    var didSelectTitle: ((_ title: String) -> Void)?

    var items: [String] = [] {
        didSet {
            collectionView.reloadData()

            if !items.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.selectFirstItemAt(section: 0)
                }

            }
        }
    }

    var query: String = "" {
        didSet {
            checkItemsContainsQuery()
            updateQueryUI()
        }
    }

    private var isMatchItem = false
    private var indexPath = IndexPath(item: 0, section: 0)
    private var collectionViewItems = [
        BidirectionalPopoverItem.identifier,
        BidirectionalPopoverActionItem.identifier
    ]

    private var nibName: String {
        return String(describing: type(of: self))
    }

    // MARK: - Initializer
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        loadXib()
        setupView()
        setupCollectionView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - UI
    private func setupView() {
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.bidirectionalPopoverBackgroundColor.cgColor
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
        collectionView.backgroundColors = [.clear]
        collectionView.layer?.backgroundColor = .clear
        collectionView.collectionViewLayout = layout
    }

    private func updateQueryUI() {
        print(indexPath)
        if items.isEmpty && !isMatchItem { resetIndexPath(section: 1) }

        if !query.isEmpty && indexPath == IndexPath(item: 0, section: 1) && !isMatchItem {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.selectFirstItemAt(section: 1)
            }
        }
    }

    // MARK: - Methods
    override func doCommand(_ command: TextRoot.Command) {
        switch command {
        case .moveUp:
            keyMoveUp()
        case .moveDown:
            keyMoveDown()
        case .insertNewline:
            selectItem()
        default:
            break
        }
    }

    private func keyMoveUp() {
        if indexPath.section == 1 {
            collectionView.deselectItems(at: [indexPath])
            indexPath = IndexPath(item: items.count, section: 0)
        }

        guard indexPath.item != 0 else { return }

        collectionView.deselectItems(at: [indexPath])
        collectionView.selectItems(at: [IndexPath(item: indexPath.item - 1, section: indexPath.section)], scrollPosition: .bottom)
        indexPath.item -= 1
    }

    private func keyMoveDown() {
        if indexPath.item == items.count - 1 && !isMatchItem {
            collectionView.deselectItems(at: [indexPath])
            indexPath = IndexPath(item: 0, section: 1)
            collectionView.selectItems(at: [indexPath], scrollPosition: .bottom)
        }

        guard indexPath.section == 0 && indexPath.item != items.count - 1 else { return }

        indexPath.item += 1
        collectionView.deselectItems(at: [IndexPath(item: indexPath.item - 1, section: indexPath.section)])
        collectionView.selectItems(at: [IndexPath(item: indexPath.item, section: indexPath.section)], scrollPosition: .bottom)
    }

    private func selectFirstItemAt(section: Int = 0) {
        indexPath = IndexPath(item: 0, section: section)
        collectionView.selectItems(at: [indexPath], scrollPosition: .bottom)
    }

    private func resetIndexPath(section: Int = 0) {
        indexPath = IndexPath(item: 0, section: section)
    }

    private func selectItem() {
        let itemName = itemNameAt(index: indexPath.section)

        switch itemName {
        case BidirectionalPopoverItem.identifier:
            guard let didSelectTitle = didSelectTitle else { break }
            didSelectTitle(query)
        case BidirectionalPopoverActionItem.identifier:
            guard let documentTitle = selectDocument(at: IndexPath(item: indexPath.item - 1, section: indexPath.section)),
                  let didSelectTitle = didSelectTitle else { break }

            didSelectTitle(documentTitle)
        default:
            break
        }
    }

    private func checkItemsContainsQuery() {
        guard !items.isEmpty else { return }
        isMatchItem = items.contains(where: query.contains)

        if isMatchItem {
            collectionView.selectItems(at: [IndexPath(item: 0, section: 0)], scrollPosition: .bottom)
            resetIndexPath()
        } else {
            resetIndexPath()
        }
    }

    private func selectDocument(at indexPath: IndexPath) -> String? {
        guard let item = collectionView.item(at: indexPath) as? BidirectionalPopoverItem else { return nil }
        return item.documentTitle
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
        return collectionViewItems.count
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        let itemName = itemNameAt(index: section)

        switch itemName {
        case BidirectionalPopoverItem.identifier:
            return items.count
        case BidirectionalPopoverActionItem.identifier:
            return isMatchItem ? 0 : 1
        default:
            return 1
        }
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let itemName = itemNameAt(index: indexPath.section)
        let item = collectionView.makeItem(withIdentifier: itemName, for: indexPath)

        switch item {
        case is BidirectionalPopoverItem:
            guard let popoverItem = item as? BidirectionalPopoverItem else { return item }
            popoverItem.documentTitle = items[indexPath.item]
            return item
        default:
            guard let popoverActionItem = item as? BidirectionalPopoverActionItem else { return item }
            popoverActionItem.updateLabel(with: query)
            return item
        }

    }

}

// MARK: - NSCollectionView FlowLayout
extension BidirectionalPopover: NSCollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        return NSSize(width: collectionView.bounds.width, height: 36)
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
        guard let indexPath = indexPaths.first,
              let documentTitle = selectDocument(at: indexPath),
              let didSelectTitle = didSelectTitle else { return }

        didSelectTitle(documentTitle)
    }

}
