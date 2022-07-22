//
//  TabsListContextMenuBuilder.swift
//  Beam
//
//  Created by Remi Santos on 19/07/2022.
//

import SwiftUI
import BeamCore

final class TabsListContextMenuBuilder {
    private weak var state: BeamState?
    init(state: BeamState) {
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

    private func addGroup(_ group: TabGroup,
                          toNote targetNote: BeamNote?,
                          from window: NSWindow,
                          completion: (PointAndShootCardPicker.ExternalCaptureConfirmation?) -> Void) {
        guard let note = targetNote, let tabsManager = state?.browserTabsManager else {
            let anim = PointAndShootCardPicker.captureWindowDisappearAnimationAndClose(in: window)
            window.contentView?.layer?.add(anim, forKey: "disappear")
            return
        }
        let tabGroupingManager = tabsManager.tabGroupingManager
        let copiedGroup = tabGroupingManager.copyForSharing(group)
        if copiedGroup.title == nil {
            let title = tabsManager.describingTitle(forGroup: group, truncated: false)
            tabGroupingManager.renameGroup(copiedGroup, title: title)
        }
        note.tabGroups.append(copiedGroup.id)
        Logger.shared.logInfo("Added group \(copiedGroup.title ?? "Unnamed"), id: \(copiedGroup.id.uuidString) into note \(note) id: \(note.id)", category: .tabGrouping)
        completion(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            let anim = PointAndShootCardPicker.captureWindowDisappearAnimationAndClose(in: window)
            window.contentView?.layer?.add(anim, forKey: "disappear")
        }
    }
}

// MARK: - Tab Context Menu
extension TabsListContextMenuBuilder {

    func contextMenuItems(forTab tab: BrowserTab, atListIndex listIndex: Int, sections: TabsListItemsSections,
                          onCloseItem: @escaping (_ atIndex: Int) -> Void) -> some View {
        let item = sections.allItems[listIndex]
        let firstGroup = Group {
            Button("Capture Page") { [weak tab] in
                tab?.collectTab()
            }.disabled(tab.url == nil || state?.browserTabsManager.currentTab != tab || tab.isLoading)
            Button("Refresh Tab") { [weak tab] in
                tab?.reload()
            }.disabled(tab.url == nil)
            Button("Duplicate Tab") { [weak self, weak tab] in
                guard let tab = tab else { return }
                self?.state?.duplicate(tab: tab)
            }

            Button("\(tab.isPinned ? "Unpin" : "Pin") Tab") { [weak tab, weak self] in
                guard let tab = tab else { return }
                if tab.isPinned == true {
                    self?.state?.browserTabsManager.unpinTab(tab)
                } else {
                    self?.state?.browserTabsManager.pinTab(tab)
                }
            }.disabled(!tab.isPinned && tab.url == nil)
            Button(tab.mediaPlayerController?.isMuted == true ? "Unmute Tab" : "Mute Tab") { [weak tab] in
                tab?.mediaPlayerController?.toggleMute()
            }.disabled(tab.mediaPlayerController?.isPlaying != true)
        }

        let secondGroup = Group {
            Button("Copy Address") { [weak tab] in
                tab?.copyURLToPasteboard()
            }.disabled(tab.url == nil)
            Button("Paste and Go") { [weak self, weak tab] in
                guard let tab = tab else { return }
                self?.pasteAndGo(on: tab)
            }
        }

        return Group {
            firstGroup
            Divider()
            if !tab.isPinned {
                groupingMenuItems(item: item)
                Divider()
            }
            secondGroup
            Divider()
            contextMenuItemCloseGroup(forTabAtListIndex: listIndex, sections: sections, onCloseItem: onCloseItem)
            if Configuration.branchType == .develop {
                Divider()
                contextMenuItemDebugGroup()
            }
        }
    }

    @ViewBuilder
    private func groupingMenuItems(item: TabsListItem) -> some View {
        let availableGroups = availableTabGroups(forItem: item)
        if item.group != nil {
            Button("Ungroup") { [weak self] in
                guard let tab = item.tab else { return }
                self?.state?.browserTabsManager.moveTabToGroup(tab.id, group: nil)
            }
            if !availableGroups.isEmpty {
                Menu("Move to Group") {
                    listOfTabGroupsAsMenu(item: item, availableGroups: availableGroups)
                }
            }
        } else {
            Button("Create Tab Group") { [weak self] in
                guard let tab = item.tab else { return }
                self?.state?.browserTabsManager.createNewGroup(withTabs: [tab])
            }
            if !availableGroups.isEmpty {
                Menu("Add to Group") {
                    listOfTabGroupsAsMenu(item: item, availableGroups: availableGroups)
                }
            }
        }
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

    @ViewBuilder
    private func listOfTabGroupsAsMenu(item: TabsListItem, availableGroups: [TabGroup]) -> some View {
        ForEach(availableGroups) { group in
            if group != item.group {
                let color = (group.color?.mainColor ?? BeamColor.TabGrouping.red).nsColor
                let title = self.title(forGroup: group)
                Button(action: { [weak self] in
                    guard let tab = item.tab else { return }
                    self?.state?.browserTabsManager.moveTabToGroup(tab.id, group: group, reorderInList: true)
                }, label: {
                    HStack {
                        Image(nsImage: self.groupCircleImage(forColor: color))
                            .renderingMode(.original)
                        Text(title)
                    }
                })
            }
        }
    }

    @ViewBuilder
    private func contextMenuItemCloseGroup(forTabAtListIndex listIndex: Int, sections: TabsListItemsSections,
                                           onCloseItem: @escaping (_ atIndex: Int) -> Void) -> some View {
        Button("Close Tab") {
            onCloseItem(listIndex)
        }
        Button("Close Other Tabs") { [weak self] in
            guard let tabIndex = self?.state?.browserTabsManager.tabIndex(forListIndex: listIndex) else { return }
            self?.state?.closeAllTabs(exceptedTabAt: tabIndex)
        }.disabled(sections.unpinnedItems.isEmpty || sections.allItems.count <= 1)
        Button("Close Tabs to the Right") { [weak self] in
            guard let tabIndex = self?.state?.browserTabsManager.tabIndex(forListIndex: listIndex) else { return }
            self?.state?.closeTabsToTheRight(of: tabIndex)
        }.disabled(listIndex + 1 >= sections.allItems.count || sections.unpinnedItems.isEmpty)
    }

    @ViewBuilder
    private func contextMenuItemDebugGroup() -> some View {
        if PreferencesManager.enableTabGroupingFeedback {
            Button("Tab Grouping Feedback") {
                AppDelegate.main.showTabGroupingFeedbackWindow(self)
            }
        }
    }
}

// MARK: - Group Context Menu
extension TabsListContextMenuBuilder {

    func showContextMenu(forGroup group: TabGroup, with event: NSEvent?) {
        let menu = NSMenu()

        let nameAndColorItem = buildNameAndColorPickerItem(in: menu, forGroup: group)
        menu.addItem(nameAndColorItem)
        menu.addItem(.fullWidthSeparator())

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
