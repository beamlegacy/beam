//
//  BidirectionalPopover.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 28/12/2020.
//

import Cocoa

protocol BidirectionalDelegate: class {
    func didSelectTitle(_ title: String)
}

class BidirectionalPopover: Popover {

    // MARK: - Properties
    @IBOutlet var containerView: NSView!
    @IBOutlet weak var collectionView: NSCollectionView!

    weak var delegate: BidirectionalDelegate?

    var items: [DocumentStruct] = [] {
        didSet {
            collectionView.reloadData()
            index = 0
        }
    }

    private var index = 0

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

    deinit {
        delegate = nil
    }

    // MARK: - UI
    private func setupView() {
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.white.cgColor
    }

    private func setupCollectionView() {
        collectionView.register(BidirectionalPopoverItem.self, forItemWithIdentifier: BidirectionalPopoverItem.identifier)
        collectionView.dataSource = self
        collectionView.delegate = self

        collectionView.isSelectable = true
        collectionView.wantsLayer = true
        collectionView.backgroundColors = [.clear]
        collectionView.layer?.backgroundColor = .clear
    }

    // MARK: - Methods
    override func doCommand(_ command: TextRoot.Command) {
        switch command {
        case .moveUp:
            keyMoveUp()
        case .moveDown:
            keyMoveDown()
        case .insertNewline:
            guard let document = selectDocument(at: IndexPath(item: index - 1, section: 0)) else { break }
            delegate?.didSelectTitle(document.title)
        default:
            break
        }
    }

    private func keyMoveUp() {
        guard index != 0 && index != 1 else { return }
        index -= 1
        collectionView.deselectItems(at: [IndexPath(item: index, section: 0)])
        collectionView.selectItems(at: [IndexPath(item: index - 1, section: 0)], scrollPosition: .bottom)
    }

    private func keyMoveDown() {
        guard index != items.count else { return }
        collectionView.deselectItems(at: [IndexPath(item: index - 1, section: 0)])
        collectionView.selectItems(at: [IndexPath(item: index, section: 0)], scrollPosition: .bottom)
        index += 1
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

}

// MARK: - NSCollectionView DataSource
extension BidirectionalPopover: NSCollectionViewDataSource {

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        guard let item = collectionView.makeItem(
                withIdentifier: BidirectionalPopoverItem.identifier,
                for: indexPath
        ) as? BidirectionalPopoverItem else {
            fatalError("Failed to load \(BidirectionalPopoverItem.identifier)")
        }

        item.document = items[indexPath.item]
        return item
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
              let document = selectDocument(at: indexPath) else { return }

        delegate?.didSelectTitle(document.title)
    }

}
