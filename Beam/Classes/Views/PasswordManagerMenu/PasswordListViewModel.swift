//
//  PasswordListViewModel.swift
//  Beam
//
//  Created by Beam on 06/08/2021.
//

import Foundation
import SwiftUI

final class PasswordListViewModel: ObservableObject {
    private var passwordManager: PasswordManager
    private var allPasswordEntries: [PasswordManagerEntry] = []
    private var allPasswordTableViewItems: [PasswordTableViewItem] = []
    private var filteredIndices: [Int] = []
    private var allToFilteredMapping: [Int: Int] = [:]
    private var currentFilteredSelection = IndexSet() // indices are relative to filtered list -- used only for comparison
    private var currentSelection = IndexSet() // indices are relative to full list, regardless of filtering options

    @Published var disableFillButton = true
    @Published var disableRemoveButton = true

    var searchString = "" {
        didSet {
            guard searchString != oldValue else {
                return
            }
            updateIndices()
        }
    }

    var selectedEntries: [PasswordManagerEntry] {
        currentSelection.map { allPasswordEntries[$0] }
    }

    var filteredPasswordEntries: [PasswordManagerEntry] {
        filteredIndices.map { allPasswordEntries[$0] }
    }

    var filteredPasswordTableViewItems: [PasswordTableViewItem] {
        filteredIndices.map { allPasswordTableViewItems[$0] }
    }

    init(passwordManager: PasswordManager = .shared) {
        self.passwordManager = passwordManager
        refresh()
    }

    func updateSelection(_ idx: IndexSet) {
        guard idx != currentFilteredSelection else {
            return
        }
        currentFilteredSelection = idx
        currentSelection = IndexSet(idx.map { filteredIndices[$0] })
        disableFillButton = idx.count != 1
        disableRemoveButton = idx.count == 0
    }

    func refresh() {
        currentSelection.removeAll()
        let entries = passwordManager.fetchAll()
        self.allPasswordEntries = entries
        self.allPasswordTableViewItems = entries.map(PasswordTableViewItem.init)
        self.updateIndices()
    }

    private func updateIndices() {
        currentFilteredSelection.removeAll()
        filteredIndices = allPasswordEntries.filteredIndices(by: searchString)
        allToFilteredMapping = Dictionary(uniqueKeysWithValues: filteredIndices.enumerated().map { ($0.1, $0.0) })
        objectWillChange.send()
    }
}

fileprivate extension Array where Element == PasswordManagerEntry {
    func filteredIndices(by searchString: String) -> [Int] {
        guard !searchString.isEmpty else {
            return [Int](0..<count)
        }
        return enumerated().filter { (_, item) in
            item.username.contains(searchString) || item.minimizedHost.contains(searchString)
        }.map { $0.0 }
    }
}
