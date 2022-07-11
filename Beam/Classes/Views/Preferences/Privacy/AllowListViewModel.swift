//
//  AllowListViewModel.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 21/06/2021.
//

import Foundation
import BeamCore
import Combine

class AllowListViewModel: ObservableObject {

    @Published private(set) var allowListItems: [AllowListViewItem] = []

    private var currentAllowListItems: [AllowListViewItem] = []
    private var subscribers = Set<AnyCancellable>()

    func refreshAllAllowListItems() {
        RadBlockDatabase.shared.allowlistEntryEnumerator(forGroup: nil, domain: nil, sortOrder: .createDate) { entries, error in
            if let entries = entries?.allObjects as? [RBAllowlistEntry] {
                let listItems = entries.map { AllowListViewItem(entry: $0) }

                DispatchQueue.main.async {
                    self.currentAllowListItems = listItems
                    self.allowListItems = listItems
                }
            }
            if let error = error {
                Logger.shared.logError("Getting allowlist entries error: \(error.localizedDescription)", category: .contentBlocking)
            }
        }
    }

    func add(domain: String) {
        if let item = currentAllowListItems.first(where: { $0.host == domain }),
           !allowListItems.contains(item) {
            allowListItems.append(item)
        } else {
            let item = AllowListViewItem(domain: domain)
            allowListItems.append(item)
        }
    }

    func update(domain: String, at index: Int) {
        allowListItems[index] = AllowListViewItem(domain: domain)
    }

    func remove(items: [AllowListViewItem]) {
        allowListItems.removeAll(where: { items.contains($0) })
    }

    func save() {
        let current = Set(currentAllowListItems)
        let new = Set(allowListItems)

        let additions = new.subtracting(current)
        let removals = current.subtracting(new)

        // Process removals first, this ensures we do not lose anything in case we have equivalent items.
        if !removals.isEmpty {
            let entries = removals.compactMap(\.entry)
            ContentBlockingManager.shared.radBlockPreferences.remove(entries: entries, completion: { })
        }
        if !additions.isEmpty {
            for item in additions {
                ContentBlockingManager.shared.radBlockPreferences.add(domain: item.host)
            }
        }

        currentAllowListItems = allowListItems
    }
}
