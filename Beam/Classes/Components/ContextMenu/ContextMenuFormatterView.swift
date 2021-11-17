//
//  ContextMenuFormatterView.swift
//  Beam
//
//  Created by Remi Santos on 22/03/2021.
//

import SwiftUI

// MARK: - NSView Container
class ContextMenuFormatterView: FormatterView {

    private var hostView: NSHostingView<ContextMenuView>?
    private var items: [ContextMenuItem] = []
    private var displayedItems: [ContextMenuItem] = []
    private var subviewModel = ContextMenuViewModel()
    private var direction: Edge = .bottom
    private var defaultSelectedIndex: Int?
    private var sizeToFit: Bool = false
    private var onSelectMenuItem: (() -> Void)?

    private var sizeUpdateDispatchedBlock: DispatchWorkItem?
    private var lastComputedSize: CGSize = .zero
    override var idealSize: CGSize {
        lastComputedSize
    }

    private var _handlesTyping: Bool = false
    override var handlesTyping: Bool {
        _handlesTyping
    }

    var typingPrefix = 1

    init(key: String,
         items: [ContextMenuItem],
         direction: Edge = .bottom,
         handlesTyping: Bool = false,
         defaultSelectedIndex: Int? = nil,
         sizeToFit: Bool = false,
         onSelectHandler: (() -> Void)? = nil) {

        self.items = items
        self.displayedItems = items
        self.direction = direction
        self.defaultSelectedIndex = defaultSelectedIndex
        self.sizeToFit = sizeToFit
        self.onSelectMenuItem = onSelectHandler
        self._handlesTyping = handlesTyping
        self.lastComputedSize = ContextMenuView.idealSizeForItems(items)
        super.init(key: key, viewType: .inline)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        subviewModel.visible = false
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
        subviewModel.onSelectMenuItem = onSelectMenuItem
        subviewModel.containerSize = idealSize
        let rootView = ContextMenuView(viewModel: subviewModel)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = self.bounds
        self.addSubview(hostingView)
        hostView = hostingView
        self.layer?.masksToBounds = false
    }

    private func updateSize() {
        let newSize = ContextMenuView.idealSizeForItems(displayedItems)
        if let window = window as? PopoverWindow {
            var newWindowFrame = window.frame
            sizeUpdateDispatchedBlock?.cancel()
            let updateWindowSizeBlock = DispatchWorkItem { [weak self] in
                self?.lastComputedSize = newSize
                self?.subviewModel.containerSize = newSize
                newWindowFrame.size.height = newSize.height + CustomPopoverPresenter.windowViewPadding * 2
                self?.hostView?.frame.size.height = newSize.height
                window.setContentSize(newWindowFrame.size)
            }
            if newSize.height < lastComputedSize.height {
                // give some time for the view to animate then change the window size
                sizeUpdateDispatchedBlock = updateWindowSizeBlock
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .milliseconds(400)), execute: updateWindowSizeBlock)
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
}
