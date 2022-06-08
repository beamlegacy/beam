//
//  ContextMenuFormatterView.swift
//  Beam
//
//  Created by Remi Santos on 22/03/2021.
//

import SwiftUI
import Combine

// MARK: - NSView Container
class ContextMenuFormatterView: FormatterView {

    private var hostView: NSHostingView<ContextMenuView>?
    private var items: [ContextMenuItem] = []
    private var displayedItems: [ContextMenuItem] = []
    private var subviewModel: ContextMenuViewModel
    private var direction: Edge = .bottom
    private var defaultSelectedIndex: Int?
    private var sizeToFit: Bool = false
    private var forcedWidth: CGFloat?
    private var canBecomeKey: Bool = false
    private var onSelectMenuItem: (() -> Void)?
    private var onClosing: (() -> Void)?

    var origin: CGPoint?

    var shouldToggleAlignment: Bool = false {
        didSet {
            subviewModel.frameAlignment = shouldToggleAlignment ? .bottomLeading : .topLeading
        }
    }

    private var cancellables = Set<AnyCancellable>()

    private var sizeUpdateDispatchedBlock: DispatchWorkItem?
    private var lastComputedSize: CGSize = .zero
    override var idealSize: CGSize {
        lastComputedSize
    }

    private var _handlesTyping: Bool = false
    override var handlesTyping: Bool {
        _handlesTyping
    }

    override var canBecomeKeyView: Bool {
        canBecomeKey
    }

    var typingPrefix = 1

    init(
        key: String,
        subviewModel: ContextMenuViewModel? = nil,
        items: [ContextMenuItem],
        direction: Edge = .bottom,
        handlesTyping: Bool = false,
        defaultSelectedIndex: Int? = nil,
        sizeToFit: Bool = false, forcedWidth: CGFloat? = nil,
        shouldToggleAlignment: Bool = false,
        origin: CGPoint? = nil, canBecomeKey: Bool = false,
        onSelectHandler: (() -> Void)? = nil, onClosing: (() -> Void)? = nil
    ) {
        self.subviewModel = subviewModel ?? ContextMenuViewModel()
        self.items = items
        self.displayedItems = items
        self.direction = direction
        self.defaultSelectedIndex = defaultSelectedIndex
        self.sizeToFit = sizeToFit
        self.forcedWidth = forcedWidth
        self.shouldToggleAlignment = shouldToggleAlignment
        self.onSelectMenuItem = onSelectHandler
        self.onClosing = onClosing
        self._handlesTyping = handlesTyping
        self.lastComputedSize = ContextMenuView.idealSizeForItems(items, forcedWidth: forcedWidth)
        self.origin = origin
        self.canBecomeKey = canBecomeKey
        super.init(key: key, viewType: .inline)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didClose() {
        super.didClose()
        subviewModel.visible = false
        subviewModel.hideSubMenu?()
        onClosing?()
    }

    override func animateOnAppear(completionHandler: (() -> Void)? = nil) {
        super.animateOnAppear()
        subviewModel.visible = true
        DispatchQueue.main.asyncAfter(deadline: .now() + FormatterView.appearAnimationDuration) {
            completionHandler?()
        }
    }

    override func animateOnDisappear(completionHandler: (() -> Void)? = nil) {
        super.animateOnDisappear()
        didClose()
        DispatchQueue.main.asyncAfter(deadline: .now() + FormatterView.disappearAnimationDuration) {
            completionHandler?()
        }
    }

    override func setupUI() {
        super.setupUI()

        subviewModel.items = displayedItems
        subviewModel.selectedIndex = defaultSelectedIndex ?? (handlesTyping ? 0 : nil)
        subviewModel.animationDirection = direction
        subviewModel.sizeToFit = sizeToFit
        subviewModel.forcedWidth = forcedWidth
        subviewModel.onSelectMenuItem = onSelectMenuItem
        subviewModel.containerSize = idealSize
        subviewModel.hideSubMenu = { [weak self] in
            self?.hideSubMenu()
        }

        subviewModel.$updateSize.sink { [weak self] updateSize in
            if updateSize {
                self?.invalidateLayout()
            }
        }.store(in: &cancellables)

        let rootView = ContextMenuView(viewModel: subviewModel) { item in
            self.presentSubMenu(item: item)
        }
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = self.bounds
        self.addSubview(hostingView)
        hostView = hostingView
        self.layer?.masksToBounds = false
    }

    private func updateSize() {
        let newSize = ContextMenuView.idealSizeForItems(displayedItems, forcedWidth: forcedWidth)
        if let window = window as? PopoverWindow {
            var newWindowFrame = window.frame
            sizeUpdateDispatchedBlock?.cancel()
            let updateWindowSizeBlock = DispatchWorkItem { [unowned self] in
                self.lastComputedSize = newSize
                self.subviewModel.containerSize = newSize
                newWindowFrame.size.height = newSize.height + CustomPopoverPresenter.padding().height * 2
                self.hostView?.frame.size.height = newSize.height
                if self.shouldToggleAlignment {
                    window.setFrame(newWindowFrame, display: true)
                } else {
                    window.setContentSize(newWindowFrame.size)
                }
            }
            if newSize.height < lastComputedSize.height {
                // give some time for the view to animate then change the window size
                sizeUpdateDispatchedBlock = updateWindowSizeBlock
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(600), execute: updateWindowSizeBlock)
            } else {
                updateWindowSizeBlock.perform()
            }
        } else {
            var newFrame = frame
            newFrame.size.height = newSize.height
            newFrame.origin.y = bounds.size.height - newFrame.size.height
            subviewModel.containerSize = newSize
            hostView?.frame = newFrame
        }
    }

    func invalidateLayout() {
        updateSize()
    }

    private func updateItemsForSearchText(_ text: String) {
        let prefix = text.lowercased()
        displayedItems = items.filter({ item in
            item.title.lowercased().hasPrefix(prefix)
        })
        subviewModel.items = displayedItems
        subviewModel.selectedIndex = handlesTyping ? 0 : nil
        updateSize()
    }

    private func selectNextItem() {
        var index = (subviewModel.selectedIndex ?? -1) + 1
        index = index.clamp(0, displayedItems.count - 1)
        while displayedItems[index].type == .separator && index < displayedItems.count - 1 {
            index += 1
        }
        subviewModel.selectedIndex = index
    }

    private func selectPreviousItem() {
        var index = (subviewModel.selectedIndex ?? (displayedItems.count)) - 1
        index = index.clamp(0, displayedItems.count - 1)
        while displayedItems[index].type == .separator && index < displayedItems.count - 1 {
            index -= 1
        }
        subviewModel.selectedIndex = index
    }

    func triggerAction(for item: ContextMenuItem) {
        item.action?()
        onSelectMenuItem?()
    }

    // MARK: - keyboard actions
    override func formatterHandlesCursorMovement(direction: CursorMovement,
                                                 modifierFlags: NSEvent.ModifierFlags? = nil) -> Bool {
        switch direction {
        case .down:
            selectNextItem()
            return subviewModel.selectedIndex != nil
        case .up:
            selectPreviousItem()
            return subviewModel.selectedIndex != nil
        default:
            return false
        }
    }

    override func formatterHandlesEnter() -> Bool {
        guard let selectedIndex = subviewModel.selectedIndex,
              selectedIndex < displayedItems.count
        else { return false }
        triggerAction(for: displayedItems[selectedIndex])
        return true
    }

    override func formatterHandlesInputText(_ text: String) -> Bool {
        let searchText = text.dropFirst(typingPrefix)
        guard handlesTyping,
              !text.isEmpty,
              !searchText.hasPrefix(" "),
              !searchText.hasSuffix(" ")
              else { return false }
        updateItemsForSearchText(String(searchText))
        return true
    }

    // MARK: - SubMenu Presentation
    private var subMenuIdentifier: String = "SubMenu-\(UUID())"
    private var horizontalPadding: CGFloat = 2.5

    private func presentSubMenu(item: ContextMenuItem) {
        guard item.type == .itemWithDisclosure,
              let subMenuModel = item.subMenuModel,
                let window = self.window else { return }

        var origin = self.origin ?? CGPoint.zero
        origin.x += (self.forcedWidth ?? self.hostView?.frame.width ?? 0) + horizontalPadding
        var idealSize = CGSize.zero
        if let idx = self.items.firstIndex(where: {$0.id == item.id}) {
            let slice = self.items.prefix(upTo: idx)
            idealSize = ContextMenuView.idealSizeForItems(Array(slice))
        }
        origin.y -= idealSize.height

        CustomPopoverPresenter.shared.dismissPopovers(key: subMenuIdentifier)

        let menuView = ContextMenuFormatterView(key: self.subMenuIdentifier, subviewModel: subMenuModel, items: subMenuModel.items, direction: .bottom, sizeToFit: subMenuModel.sizeToFit, forcedWidth: subMenuModel.forcedWidth, origin: origin, canBecomeKey: false, onSelectHandler: {
            CustomPopoverPresenter.shared.dismissPopovers(key: self.subMenuIdentifier)
            self.onSelectMenuItem?()
        })

        CustomPopoverPresenter.shared.presentFormatterView(menuView, atPoint: origin, in: window)
        subviewModel.subMenuIsShown = true
    }

    func hideSubMenu() {
        CustomPopoverPresenter.shared.dismissPopovers(key: self.subMenuIdentifier)
        subviewModel.subMenuIsShown = false
    }
}
