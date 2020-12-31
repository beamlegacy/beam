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

    var items: [DocumentStruct] = [] {
        didSet {
            collectionView.reloadData()
        }
    }

    var query: String = "" {
        didSet {
            updateQueryUI()
        }
    }

    private var indexPath = IndexPath(item: 0, section: 0)
    private var collectionViewItems = [
        BidirectionalPopoverActionItem.identifier,
        BidirectionalPopoverItem.identifier
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
        _ = collectionViewItems.map({ collectionView.register(NSNib(nibNamed: $0.rawValue, bundle: nil), forItemWithIdentifier: $0) })
        collectionView.dataSource = self
        collectionView.delegate = self

        collectionView.isSelectable = true
        collectionView.wantsLayer = true
        collectionView.backgroundColors = [.clear]
        collectionView.layer?.backgroundColor = .clear
    }

    private func updateQueryUI() {
        if items.count == 0 { resetIndexPath() }

        if !query.isEmpty && indexPath == indexPath {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.selectFirstItem()
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
        if indexPath.item == 1 {
            collectionView.deselectItems(at: [IndexPath(item: indexPath.item - 1, section: indexPath.section)])
            resetIndexPath()
            selectFirstItem()
        }

        guard indexPath.item != 0 && indexPath.item != 1 else { return }

        indexPath.item -= 1
        collectionView.deselectItems(at: [indexPath])
        collectionView.selectItems(at: [IndexPath(item: indexPath.item - 1, section: indexPath.section)], scrollPosition: .bottom)
    }

    private func keyMoveDown() {
        if items.count == 0 {
            resetIndexPath()
            selectFirstItem()
        }

        guard indexPath.item != items.count else { return }

        if indexPath.section == 0 && items.count > 0 {
            collectionView.deselectItems(at: [indexPath])
            indexPath.section = 1
        }

        collectionView.deselectItems(at: [IndexPath(item: indexPath.item - 1, section: indexPath.section)])
        collectionView.selectItems(at: [IndexPath(item: indexPath.item, section: indexPath.section)], scrollPosition: .bottom)
        indexPath.item += 1
    }

    private func selectFirstItem() {
        collectionView.selectItems(at: [indexPath], scrollPosition: .bottom)
    }

    private func resetIndexPath() {
        indexPath = IndexPath(item: 0, section: 0)
    }

    private func selectItem() {
        switch indexPath.section {
        case 0:
            guard let didSelectTitle = didSelectTitle else { break }
            didSelectTitle(query)
        default:
            guard let document = selectDocument(at: IndexPath(item: indexPath.item - 1, section: indexPath.section)),
                  let didSelectTitle = didSelectTitle else { break }

            didSelectTitle(document.title)
        }
    }

    private func selectDocument(at indexPath: IndexPath) -> DocumentStruct? {
        guard let item = collectionView.item(at: indexPath) as? BidirectionalPopoverItem else { return nil }
        return item.document
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
        case BidirectionalPopoverActionItem.identifier:
            return query.isEmpty ? 0 : 1
        case BidirectionalPopoverItem.identifier:
            return items.count
        default:
            return 0
        }
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let itemName = itemNameAt(index: indexPath.section)

        switch itemName {
        case BidirectionalPopoverActionItem.identifier:
            guard let item = collectionView.makeItem(
                    withIdentifier: itemName,
                    for: indexPath
            ) as? BidirectionalPopoverActionItem else {
                fatalError("Failed to load \(itemName)")
            }

            item.updateLabel(with: query)
            return item
        default:
            guard let item = collectionView.makeItem(
                withIdentifier: itemName,
                for: indexPath
            ) as? BidirectionalPopoverItem else {
                fatalError("Failed to load \(itemName)")
            }

            item.document = items[indexPath.item]
            return item
        }

    }

}

// MARK: - NSCollectionView FlowLayout
extension BidirectionalPopover: NSCollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        return NSSize(width: collectionView.bounds.width, height: 40)
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
              let document = selectDocument(at: indexPath),
              let didSelectTitle = didSelectTitle else { return }

        didSelectTitle(document.title)
    }

}
