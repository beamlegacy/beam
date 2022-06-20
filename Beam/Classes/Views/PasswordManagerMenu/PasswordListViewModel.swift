//
//  PasswordListViewModel.swift
//  Beam
//
//  Created by Beam on 06/08/2021.
//

import Foundation
import Combine
import SwiftUI

final class PasswordListViewModel: ObservableObject {
    struct EditedPassword: Identifiable {
        var entry: PasswordManagerEntry
        var password: String
        var id: String { entry.id }
    }

    struct AlertMessage: Identifiable {
        var message: String
        var id: String { message }

        init(error: Error) {
            if let error = error as? PasswordManager.Error {
                switch error {
                case .databaseError:
                    message = "Could not read password from database."
                case .decryptionError:
                    message = "Could not decrypt password."
                case .encryptionError:
                    message = "Could not encrypt password."
                }
            } else {
                message = error.localizedDescription
            }
        }
    }

    private var passwordManager: PasswordManager
    private var allPasswordEntries: [PasswordManagerEntry] = []
    private var allPasswordTableViewItems: [PasswordTableViewItem] = []
    private var filteredIndices: [Int] = []
    private var allToFilteredMapping: [Int: Int] = [:]
    private var currentFilteredSelection = IndexSet() // indices are relative to filtered list -- used only for comparison
    private var currentSelection = IndexSet() // indices are relative to full list, regardless of filtering options
    private var cancellables = Set<AnyCancellable>()

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
        passwordManager.changePublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in
                self.refresh()
            }
            .store(in: &cancellables)
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

    private func refresh() {
        let savedSelection = Set(selectedEntries)
        let entries = passwordManager.fetchAll()
        self.allPasswordEntries = entries
        currentSelection = IndexSet(
            entries.enumerated()
                .filter { (_, entry) in savedSelection.contains(entry) }
                .map { (index, _) in index }
        )
        self.allPasswordTableViewItems = entries.map(PasswordTableViewItem.init)
        self.updateIndices()
    }

    private func updateIndices() {
        filteredIndices = allPasswordEntries.filteredIndices(by: searchString)
        allToFilteredMapping = Dictionary(uniqueKeysWithValues: filteredIndices.enumerated().map { ($0.1, $0.0) })
        currentFilteredSelection = IndexSet(currentSelection.compactMap { allToFilteredMapping[$0] })
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
