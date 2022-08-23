//
//  TabsListContextMenuBuilder.swift
//  Beam
//
//  Created by Remi Santos on 19/07/2022.
//

import SwiftUI
import BeamCore

final class TabsListContextMenuBuilder: ObservableObject {
    private weak var state: BeamState?
    @Published var tabGroupIsSharing: TabGroup?

    init() { }
    func setup(withState state: BeamState) {
        self.state = state
    }
}

// MARK: - Actions
extension TabsListContextMenuBuilder {
    private func pasteAndGo(on tab: BrowserTab) {
        guard let state = state, let query = NSPasteboard.general.string(forType: .string) else {  return }
        state.autocompleteManager.searchQuery = query
        state.omniboxInfo.wasFocusedFromTab = true
        state.startOmniboxQuery()
    }

    private func presentCaptureWindow(for group: TabGroup, at location: CGPoint) {
        guard let window = CustomPopoverPresenter.shared.presentPopoverChildWindow(withShadow: false, movable: false),
              let state = state else {
            return
        }

        let extraPadding = 60.0
        window.extraPadding = extraPadding

        let view = buildExternalCaptureView(for: group, in: window, state: state)
        window.setView(with: view, at: CGPoint(x: location.x - extraPadding, y: location.y + extraPadding), fromTopLeft: true)

        guard let view = window.contentView else { return }
        let animation = PointAndShootCardPicker.captureWindowAppearAnimation()
        view.layer?.add(animation, forKey: "appearance")

        window.makeKeyAndOrderFront(nil)
    }

    private func buildExternalCaptureView(for group: TabGroup, in window: NSWindow, state: BeamState) -> some View {
        FormatterViewBackgroundV2 {
            PointAndShootCardPicker(allowAnimation: .constant(true), onComplete: { [weak self] targetNote, _, completion in
                self?.addGroup(group, toNote: targetNote, from: window, completion: completion)
            }, canShowCopyShareView: false, captureFromOutsideWebPage: true)
        }
        .environmentObject(state)
        .environmentObject(state.data)
        .environmentObject(state.browserTabsManager)
        .frame(width: 300)
        .fixedSize()
    }

    private func addGroup(_ group: TabGroup, toNote targetNote: BeamNote?,
                          from window: NSWindow, completion: (PointAndShootCardPicker.ExternalCaptureConfirmation?) -> Void) {
        guard let note = targetNote, let tabsManager = state?.browserTabsManager else {
            let anim = PointAndShootCardPicker.captureWindowDisappearAnimationAndClose(in: window)
            window.contentView?.layer?.add(anim, forKey: "disappear")
            return
        }
        let tabGroupingManager = tabsManager.tabGroupingManager
        if tabGroupingManager.addGroup(group, toNote: note) {
            completion(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                let anim = PointAndShootCardPicker.captureWindowDisappearAnimationAndClose(in: window)
                window.contentView?.layer?.add(anim, forKey: "disappear")
            }
        } else {
            completion(.failure)
        }
    }

    private func shareGroup(_ group: TabGroup, itemFrame: CGRect?, shareService: ShareService) {
        guard let tabGroupingManager = state?.browserTabsManager.tabGroupingManager else { return }
        let startTime = BeamDate.now
        let canShare = tabGroupingManager.shareGroup(group, shareService: shareService) { [weak self] result in
            // let's make sure the loading state was visible for at least 2s to avoid blinking.
            let delayInSeconds: Int = max(0, 2 + Int(startTime.timeIntervalSinceNow))
            let previousStatus = group.status
            if delayInSeconds > 0 {
                group.status = .sharing
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delayInSeconds)) {
                self?.tabGroupIsSharing = nil
                if delayInSeconds > 0 {
                    group.status = previousStatus
                }
                guard shareService == .copy, let itemFrame = itemFrame else { return }
                switch result {
                case .success:
                    let point = CGPoint(x: itemFrame.midX, y: itemFrame.maxY + (Tooltip.defaultHeight / 2) + 3)
                    self?.state?.overlayViewModel.presentTooltip(text: "Link Copied", at: point)
                case .failure:
                    break
                }
            }
        }
        tabGroupIsSharing = canShare ? group : nil
    }
}

// MARK: - Tab Context Menu
extension TabsListContextMenuBuilder {

    func showContextMenu(forTab tab: BrowserTab, atListIndex listIndex: Int, sections: TabsListItemsSections,
                         event: NSEvent?, onCloseItem: @escaping (_ atIndex: Int) -> Void) {
        let item = sections.allItems[listIndex]
        let menu = NSMenu()
        menu.autoenablesItems = false

        // First group
        menu.addItem(withTitle: "Capture Page",
                     enabled: tab.url != nil && state?.browserTabsManager.currentTab == tab && !tab.isLoading) { [weak tab] _ in
            tab?.collectTab()
        }
        menu.addItem(withTitle: "Refresh Tab", enabled: tab.url != nil) { [weak tab] _ in
            tab?.reload()
        }
        menu.addItem(withTitle: "Duplicate Tab") { [weak self, weak tab] _ in
            guard let tab = tab else { return }
            self?.state?.duplicate(tab: tab)
        }
        menu.addItem(withTitle: "\(tab.isPinned ? "Unpin" : "Pin") Tab",
                     enabled: tab.isPinned || tab.url != nil ) { [weak tab, weak self] _ in
            guard let tab = tab else { return }
            if tab.isPinned == true {
                self?.state?.browserTabsManager.unpinTab(tab)
            } else {
                self?.state?.browserTabsManager.pinTab(tab)
            }
        }
        menu.addItem(withTitle: tab.mediaPlayerController?.isMuted == true ? "Unmute Tab" : "Mute Tab",
                     enabled: tab.mediaPlayerController?.isPlaying == true) { [weak tab] _ in
            tab?.mediaPlayerController?.toggleMute()
        }

        menu.addItem(.separator())

        // Tab Grouping
        if !tab.isPinned {
            tabContextMenuGroupingItems(for: item, in: menu)
            menu.addItem(.separator())
        }

        // Second Group
        menu.addItem(withTitle: "Copy Address", enabled: tab.url != nil) { [weak tab] _ in
            tab?.copyURLToPasteboard()
        }
        menu.addItem(withTitle: "Paste and Go") { [weak self, weak tab] _ in
            guard let tab = tab else { return }
            self?.pasteAndGo(on: tab)
        }
        menu.addItem(.separator())

        // Close Group
        tabContextMenuCloseTabsItems(forTabAtListIndex: listIndex, sections: sections, in: menu, onCloseItem: onCloseItem)

        // Debug Group
        if Configuration.branchType == .develop {
            menu.addItem(.separator())
            tabContextMenuDebugGroupItems(in: menu)
        }

        menu.popUp(positioning: nil, at: event?.locationInWindow ?? .zero, in: event?.window?.contentView)
    }

    private func tabContextMenuGroupingItems(for item: TabsListItem, in mainMenu: NSMenu) {
        let availableGroups = availableTabGroups(forItem: item)
        var items = [NSMenuItem]()
        var sendToGroupItem: NSMenuItem?
        if !availableGroups.isEmpty {
            let menu = NSMenu()
            let subItems = listOfTabGroupsAsMenu(item: item, availableGroups: availableGroups)
            subItems.forEach { menu.addItem($0) }
            let menuItem = NSMenuItem(title: "title to replace", action: nil, keyEquivalent: "")
            mainMenu.setSubmenu(menu, for: menuItem)
            items.append(menuItem)
            sendToGroupItem = menuItem
        }
        if item.group != nil {
            items.insert(HandlerMenuItem(title: "Ungroup") { [weak self] _ in
                guard let tab = item.tab else { return }
                self?.state?.browserTabsManager.moveTabToGroup(tab.id, group: nil)
            }, at: 0)
            sendToGroupItem?.title = "Move to Group"
        } else {
            items.insert(HandlerMenuItem(title: "Create Tab Group") { [weak self] _ in
                guard let tab = item.tab else { return }
                self?.state?.browserTabsManager.createNewGroup(withTabs: [tab])
            }, at: 0)
            sendToGroupItem?.title = "Add to Group"
        }
        items.forEach { mainMenu.addItem($0) }
    }

    /// Create an image of a solid color circle. To be used as Menu Item label image
    private func groupCircleImage(forColor color: NSColor) -> NSImage {
        let frame = NSRect(origin: .zero, size: CGSize(width: 14, height: 14))
        let image = NSImage(size: frame.size)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        NSBezierPath(ovalIn: frame).addClip()
        color.usingColorSpace(.deviceRGB)?.drawSwatch(in: frame)
        image.unlockFocus()
        return image
    }

    private func availableTabGroups(forItem item: TabsListItem) -> [TabGroup] {
        var groups: [TabGroup] = []
        if let state = state {
            groups = Array(Set(state.browserTabsManager.tabGroupingManager.builtPagesGroups.values))
        }
        if item.group != nil {
            groups = groups.filter { $0 != item.group }
        }
        return groups
    }

    private func title(forGroup group: TabGroup) -> String {
        if let title = group.title, !title.isEmpty {
            return title
        }
        return self.state?.browserTabsManager.describingTitle(forGroup: group, truncated: true) ?? ""
    }

    private func listOfTabGroupsAsMenu(item: TabsListItem, availableGroups: [TabGroup]) -> [NSMenuItem] {
        availableGroups.compactMap { group in
            guard group != item.group else { return nil }
            let color = (group.color?.mainColor ?? BeamColor.TabGrouping.red).nsColor
            let title = self.title(forGroup: group)
            let item = HandlerMenuItem(title: title) { [weak self] _ in
                guard let tab = item.tab else { return }
                self?.state?.browserTabsManager.moveTabToGroup(tab.id, group: group, reorderInList: true)
            }
            item.image = self.groupCircleImage(forColor: color)
            return item
        }
    }

    private func tabContextMenuCloseTabsItems(forTabAtListIndex listIndex: Int, sections: TabsListItemsSections, in menu: NSMenu,
                                              onCloseItem: @escaping (_ atIndex: Int) -> Void) {
        menu.addItem(withTitle: "Close Tab") { _ in
            onCloseItem(listIndex)
        }
        menu.addItem(withTitle: "Close Other Tabs",
                     enabled: !sections.unpinnedItems.isEmpty && sections.allItems.count > 1) { [weak self] _ in
            guard let tabIndex = self?.state?.browserTabsManager.tabIndex(forListIndex: listIndex) else { return }
            self?.state?.closeAllTabs(exceptedTabAt: tabIndex)
        }
        menu.addItem(withTitle: "Close Tabs to the Right",
                     enabled: listIndex + 1 < sections.allItems.count && !sections.unpinnedItems.isEmpty) { [weak self] _ in
            guard let tabIndex = self?.state?.browserTabsManager.tabIndex(forListIndex: listIndex) else { return }
            self?.state?.closeTabsToTheRight(of: tabIndex)
        }
    }

    private func tabContextMenuDebugGroupItems(in menu: NSMenu) {
        if PreferencesManager.enableTabGroupingFeedback {
            menu.addItem(withTitle: "Tab Grouping Feedback") { [weak self] _ in
                guard let self = self else { return }
                AppDelegate.main.showTabGroupingFeedbackWindow(self)
            }
        }
    }
}

// MARK: - Group Context Menu
extension TabsListContextMenuBuilder {

    func showContextMenu(forGroup group: TabGroup, with event: NSEvent?, itemFrame: CGRect?) {
        guard group.status != .sharing else { return }
        let menu = NSMenu()

        let nameAndColorItem = buildNameAndColorPickerItem(in: menu, forGroup: group)
        menu.addItem(nameAndColorItem)
        menu.addItem(.fullWidthSeparator())

        addShareGroupSubMenu(in: menu, forGroup: group, itemFrame: itemFrame)

        menu.addItem(withTitle: "Capture Group to a Note…") { [weak self] _ in
            let location = event?.locationInWindow ?? .zero
            self?.presentCaptureWindow(for: group, at: location)
        }
        menu.addItem(.separator())

        menu.addItem(withTitle: "New Tab in Group") { [weak self] _ in
            self?.state?.browserTabsManager.createNewTab(inGroup: group)
        }
        menu.addItem(withTitle: "Move Group in New Window") { [weak self] _ in
            self?.state?.browserTabsManager.moveGroupToNewWindow(group)
        }

        menu.addItem(.separator())

        menu.addItem(withTitle: group.collapsed ? "Expand Group" : "Collapse Group") { [weak self] _ in
            self?.state?.browserTabsManager.toggleGroupCollapse(group)
        }
        menu.addItem(withTitle: "Ungroup") { [weak self] _ in
            self?.state?.browserTabsManager.ungroupTabsInGroup(group)
        }
        menu.addItem(withTitle: "Close Group") { [weak self] _ in
            self?.state?.browserTabsManager.closeTabsInGroup(group)
        }

        menu.popUp(positioning: nil, at: event?.locationInWindow ?? .zero, in: event?.window?.contentView)
    }

    private func addShareGroupSubMenu(in menu: NSMenu, forGroup group: TabGroup, itemFrame: CGRect?) {
        let subMenu = NSMenu()
        let handlerForService: (ShareService) -> HandlerMenuItem.Handler = { [weak self] service in
            return { _ in self?.shareGroup(group, itemFrame: itemFrame, shareService: service) }
        }
        var subItems = [
            HandlerMenuItem(title: "Copy Link", icon: "editor-url_link", handler: handlerForService(.copy)),
            NSMenuItem.separator()
        ]
        subItems.append(contentsOf: ShareService.allCases(except: [.copy]).map {
            HandlerMenuItem(title: $0.title, icon: $0.icon, handler: handlerForService($0))
        })
        subItems.forEach { subMenu.addItem($0) }
        let menuItem = NSMenuItem(title: "Share Group", action: nil, keyEquivalent: "")
        menu.setSubmenu(subMenu, for: menuItem)
        menu.addItem(menuItem)
    }

    private func buildNameAndColorPickerItem(in menu: NSMenu, forGroup group: TabGroup) -> ContentViewMenuItem<TabClusteringNameColorPickerView> {
        let nameAndColorView = TabClusteringNameColorPickerView(
            groupName: group.title ?? "",
            selectedColor: group.color?.designColor ?? .red,
            onChange: { [weak self] newValues in
                if group.title != newValues.name {
                    self?.state?.browserTabsManager.renameGroup(group, title: newValues.name)
                }
                if group.color != newValues.color, let newColor = newValues.color {
                    self?.state?.browserTabsManager.changeGroupColor(group, color: newColor)
                }
            },
            onFinish: { [weak menu] in menu?.cancelTracking() })

        let nameAndColorItemInsets = NSEdgeInsets(top: 4, left: 14, bottom: 8, right: 14)

        let item = ContentViewMenuItem(
            title: "Name your group item",
            acceptsFirstResponder: !(group.title?.isEmpty == true),
            contentView: { nameAndColorView },
            insets: nameAndColorItemInsets,
            customization: { hostingView in
                let width = 230 - (nameAndColorItemInsets.left + nameAndColorItemInsets.right)
                hostingView.widthAnchor.constraint(equalToConstant: width).isActive = true
                hostingView.heightAnchor.constraint(equalToConstant: 16).isActive = true
            })
        return item
    }
}

extension TabsListContextMenuBuilder: BeamDocumentSource {
    static var sourceId: String { "\(Self.self)" }
}
