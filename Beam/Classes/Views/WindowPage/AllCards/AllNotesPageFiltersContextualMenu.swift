//
//  AllNotesPageFiltersContextualMenu.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 17/05/2022.
//

import Foundation
import BeamCore

class AllNotesPageFiltersContextualMenu {
    private var viewModel: AllNotesPageViewModel

    init(viewModel: AllNotesPageViewModel) {
        self.viewModel = viewModel
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
        allNotesItem.state = viewModel.listType == .allNotes ? .on : .off
        menu.addItem(allNotesItem)

        let privateNotesItem = NSMenuItem(
            title: "Private (\(viewModel.getCurrentNotesList(for: .privateNotes).count))",
            action: #selector(selectPrivateNotes),
            keyEquivalent: ""
        )
        privateNotesItem.state = viewModel.listType == .privateNotes ? .on : .off
        menu.addItem(privateNotesItem)

        let publishedNotesItem = NSMenuItem(
            title: "Published (\(viewModel.getCurrentNotesList(for: .publicNotes).count))",
            action: #selector(selectPublishedNotes),
            keyEquivalent: ""
        )
        publishedNotesItem.state = viewModel.listType == .publicNotes ? .on : .off
        menu.addItem(publishedNotesItem)

        let onProfileNotesItem = NSMenuItem(
            title: "On Profile (\(viewModel.getCurrentNotesList(for: .onProfileNotes).count))",
            action: #selector(selectOnProfileNotes),
            keyEquivalent: ""
        )
        onProfileNotesItem.state = viewModel.listType == .onProfileNotes ? .on : .off
        menu.addItem(onProfileNotesItem)

        menu.addItem(NSMenuItem.separator())

        let showDailyNotesItem = NSMenuItem(
            title: "Show Daily Notes",
            action: #selector(showDailyNotes),
            keyEquivalent: "")
        showDailyNotesItem.state = viewModel.showDailyNotes ? .on : .off
        menu.addItem(showDailyNotesItem)

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
        viewModel.listType = .allNotes
    }

    @objc
    private func selectPrivateNotes() {
        viewModel.listType = .privateNotes
    }

    @objc
    private func selectPublishedNotes() {
        viewModel.listType = .publicNotes
    }

    @objc
    private func selectOnProfileNotes() {
        viewModel.listType = .onProfileNotes
    }

    @objc
    private func showDailyNotes() {
        viewModel.showDailyNotes.toggle()
    }
}
