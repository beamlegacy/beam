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
    private var onSelectMenuItem: (() -> Void)?

    override var idealSize: NSSize {
        return ContextMenuView.idealSizeForItems(displayedItems)
    }

    private var _handlesTyping: Bool = false
    override var handlesTyping: Bool {
        _handlesTyping
    }

    var typingPrefix = 1

    convenience init(items: [ContextMenuItem], direction: Edge = .bottom, handlesTyping: Bool = false, onSelectHandler: (() -> Void)? = nil) {
        self.init(frame: CGRect.zero)
        self.viewType = .inline
        self.items = items
        self.displayedItems = items
        self.direction = direction
        self.onSelectMenuItem = onSelectHandler
        self._handlesTyping = handlesTyping
        setupUI()
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
        subviewModel.animationDirection = direction
        subviewModel.onSelectMenuItem = onSelectMenuItem
        let rootView = ContextMenuView(viewModel: subviewModel)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = self.bounds
        self.addSubview(hostingView)
        hostView = hostingView
        self.layer?.masksToBounds = false
    }

    private func updateSize() {
        var frame = bounds
        frame.size.height = idealSize.height
        frame.origin.y = bounds.size.height - frame.size.height
        hostView?.frame = frame
    }

    private func updateItemsForSearchText(_ text: String) {
        let prefix = text.lowercased()
        displayedItems = items.filter({ item in
            item.title.lowercased().hasPrefix(prefix)
        })
        subviewModel.items = displayedItems
        updateSize()
    }

    private func selectNextItem() {
        guard subviewModel.selectedIndex != displayedItems.count - 1 else {
            subviewModel.selectedIndex = nil
            return
        }
        var index = (subviewModel.selectedIndex ?? -1) + 1
        index = index.clamp(0, displayedItems.count - 1)
        while displayedItems[index].type == .separator && index < displayedItems.count - 1 {
            index += 1
        }
        subviewModel.selectedIndex = index
    }

    private func selectPreviousItem() {
        guard subviewModel.selectedIndex != 0 else {
            subviewModel.selectedIndex = nil
            return
        }
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
    override func moveDown() -> Bool {
        selectNextItem()
        return subviewModel.selectedIndex != nil
    }

    override func moveUp() -> Bool {
        selectPreviousItem()
        return subviewModel.selectedIndex != nil
    }

    override func pressEnter() -> Bool {
        guard let selectedIndex = subviewModel.selectedIndex,
              selectedIndex < displayedItems.count
        else { return false }
        triggerAction(for: displayedItems[selectedIndex])
        return true
    }

    override func inputText(_ text: String) -> Bool {
        let searchText = text.dropFirst(typingPrefix)
        let hadResults = displayedItems.count > 0
        guard handlesTyping,
              !text.isEmpty,
              !searchText.hasPrefix(" "),
              !searchText.hasSuffix("  "),
              (hadResults || !searchText.hasSuffix(" "))
              else { return false }
        updateItemsForSearchText(String(searchText))
        return true
    }
}
