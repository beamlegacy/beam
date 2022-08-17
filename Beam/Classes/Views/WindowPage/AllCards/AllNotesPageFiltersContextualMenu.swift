//
//  AllNotesPageFiltersContextualMenu.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 17/05/2022.
//

import Foundation
import BeamCore

final class AllNotesPageFiltersContextualMenu {
    private var viewModel: AllNotesPageViewModel
    private var state: BeamState

    private var listType: ListType {
        get {
            state.allNotesListType
        }
        set {
            state.allNotesListType = newValue
        }
    }

    init(viewModel: AllNotesPageViewModel, state: BeamState) {
        self.viewModel = viewModel
        self.state = state
    }

    func presentMenu(at origin: CGPoint) {
        guard let window = AppDelegate.main.window else { return }
        let menu = NSMenu()
        menu.font = BeamFont.regular(size: 13).nsFont

        let allNotesItem = NSMenuItem(
            title: "All (\(viewModel.getCurrentNotesList(for: .allNotes).count))",
            action: #selector(selectAllNotes),
            keyEquivalent: ""
        )
        allNotesItem.isEnabled = true
        allNotesItem.state = listType == .allNotes ? .on : .off
        menu.addItem(allNotesItem)

        let privateNotesItem = NSMenuItem(
            title: "Private (\(viewModel.getCurrentNotesList(for: .privateNotes).count))",
            action: #selector(selectPrivateNotes),
            keyEquivalent: ""
        )
        privateNotesItem.state = listType == .privateNotes ? .on : .off
        menu.addItem(privateNotesItem)

        let publishedNotesItem = NSMenuItem(
            title: "Published (\(viewModel.getCurrentNotesList(for: .publicNotes).count))",
            action: #selector(selectPublishedNotes),
            keyEquivalent: ""
        )
        publishedNotesItem.state = listType == .publicNotes ? .on : .off
        menu.addItem(publishedNotesItem)

        let onProfileNotesItem = NSMenuItem(
            title: "On Profile (\(viewModel.getCurrentNotesList(for: .onProfileNotes).count))",
            action: #selector(selectOnProfileNotes),
            keyEquivalent: ""
        )
        onProfileNotesItem.state = listType == .onProfileNotes ? .on : .off
        menu.addItem(onProfileNotesItem)

        menu.addItem(NSMenuItem.separator())

        let showDailyNotesItem = NSMenuItem(
            title: "Show Daily Notes",
            action: #selector(showDailyNotes),
            keyEquivalent: "")
        showDailyNotesItem.state = state.showDailyNotes ? .on : .off
        menu.addItem(showDailyNotesItem)

        if Configuration.branchType == .develop {
            let showTabGroupsNotesItem = NSMenuItem(
                title: "Show Tab Groups",
                action: #selector(showTabGroupNotes),
                keyEquivalent: "")
            showTabGroupsNotesItem.state = viewModel.showTabGroupNotes ? .on : .off
            menu.addItem(showTabGroupsNotesItem)
        }

        for item in menu.items {
            item.isEnabled = true
        }

        finalizeAllMenuItems(menu.items)
        let position = CGRect(origin: origin, size: .zero).flippedRectToBottomLeftOrigin(in: window).origin
        menu.popUp(positioning: nil, at: position, in: window.contentView)
    }

    private func finalizeAllMenuItems(_ items: [NSMenuItem]) {
        items.forEach { item in
            item.target = self
            if let subItems = item.submenu?.items {
                finalizeAllMenuItems(subItems)
            }
        }
    }

    // MARK: - Action

    @objc
    private func selectAllNotes() {
        listType = .allNotes
    }

    @objc
    private func selectPrivateNotes() {
        listType = .privateNotes
    }

    @objc
    private func selectPublishedNotes() {
        listType = .publicNotes
    }

    @objc
    private func selectOnProfileNotes() {
        listType = .onProfileNotes
    }

    @objc
    private func showDailyNotes() {
        state.showDailyNotes.toggle()
    }

    @objc
    private func showTabGroupNotes() {
        viewModel.setShowTabGroupNotes(!viewModel.showTabGroupNotes)
    }
}
