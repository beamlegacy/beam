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

    init(viewModel: AllNotesPageViewModel, state: BeamState) {
        self.viewModel = viewModel
        self.state = state
    }

    func presentMenu(at origin: CGPoint) {
        guard let window = AppDelegate.main.window else { return }
        let menu = NSMenu()
        menu.font = BeamFont.regular(size: 13).nsFont

        let showDailyNotesItem = NSMenuItem(
            title: state.showDailyNotes ? loc("Hide Daily Notes") : loc("Show Daily Notes"),
            action: #selector(showDailyNotes),
            keyEquivalent: "")
        menu.addItem(showDailyNotesItem)

        if Configuration.branchType == .develop {
            let showTabGroupsNotesItem = NSMenuItem(
                title: viewModel.showTabGroupNotes ? loc("Hide Tab Groups") : loc("Show Tab Groups"),
                action: #selector(showTabGroupNotes),
                keyEquivalent: "")
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
    private func showDailyNotes() {
        state.showDailyNotes.toggle()
    }

    @objc
    private func showTabGroupNotes() {
        viewModel.setShowTabGroupNotes(!viewModel.showTabGroupNotes)
    }
}
