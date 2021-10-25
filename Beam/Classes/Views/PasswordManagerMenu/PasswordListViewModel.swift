//
//  PasswordListViewModel.swift
//  Beam
//
//  Created by Beam on 06/08/2021.
//

import Foundation
import SwiftUI

final class PasswordListViewModel: ObservableObject {
    private var allPasswordEntries: [PasswordManagerEntry] = []
    private var allPasswordTableViewItems: [PasswordTableViewItem] = []
    var filteredPasswordEntries: [PasswordManagerEntry] = []

    @Published var filteredPasswordTableViewItems: [PasswordTableViewItem] = []
    private var currentSelection = IndexSet()
    @Published var disableFillButton = true
    @Published var disableRemoveButton = true

    var searchString = "" {
        didSet {
            guard searchString != oldValue else {
                return
            }
            filteredPasswordEntries = allPasswordEntries.filtered(by: searchString)
            filteredPasswordTableViewItems = allPasswordTableViewItems.filtered(by: searchString)
        }
    }

    var selectedEntries: [PasswordManagerEntry] {
        currentSelection.map { filteredPasswordEntries[$0] }
    }

    init() {
        refresh()
    }

    func updateSelection(_ idx: IndexSet) {
        guard idx != currentSelection else {
            return
        }
        currentSelection = idx
        disableFillButton = idx.count != 1
        disableRemoveButton = idx.count == 0
    }

    func refresh() {
        currentSelection.removeAll()
        let entries = PasswordManager.shared.fetchAll()
        self.allPasswordEntries = entries
        self.allPasswordTableViewItems = entries.map(PasswordTableViewItem.init)
        self.filteredPasswordEntries = self.allPasswordEntries.filtered(by: self.searchString)
        self.filteredPasswordTableViewItems = self.allPasswordTableViewItems.filtered(by: self.searchString)
    }
}

fileprivate extension Sequence where Element == PasswordManagerEntry {
    func filtered(by searchString: String) -> [Element] {
        guard !searchString.isEmpty else {
            return Array(self)
        }
        return filter { item in
            item.username.contains(searchString) || item.minimizedHost.contains(searchString)
        }
    }
}

fileprivate extension Sequence where Element == PasswordTableViewItem {
    func filtered(by searchString: String) -> [Element] {
        guard !searchString.isEmpty else {
            return Array(self)
        }
        return filter { item in
            item.username.contains(searchString) || item.hostname.contains(searchString)
        }
    }
}
