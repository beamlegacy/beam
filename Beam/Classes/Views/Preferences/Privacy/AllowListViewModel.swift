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

    @Published var allAllowListItems: [AllowListViewItem] = []
    @Published var recentlyAddedItems: [AllowListViewItem] = []
    private var subscribers = Set<AnyCancellable>()

    init() {
        refreshAllAllowListItems()
    }

    func refreshAllAllowListItems() {
        RadBlockDatabase.shared.allowlistEntryEnumerator(forGroup: nil, domain: nil, sortOrder: .createDate) { entries, error in
            if let entries = entries?.allObjects as? [RBAllowlistEntry] {
                DispatchQueue.mainSync {
                    self.allAllowListItems.removeAll()
                }
                for entry in entries {
                    let item = AllowListViewItem(entry: entry)
                    DispatchQueue.main.async {
                        self.allAllowListItems.append(item)
                    }
                }
            }
            if let error = error {
                Logger.shared.logError("Getting allowlist entries error: \(error.localizedDescription)", category: .contentBlocking)
            }
        }
    }

    func add(domain: String) {
        let item = AllowListViewItem(domain: domain)
        DispatchQueue.main.async {
            self.recentlyAddedItems.append(item)
            self.allAllowListItems.append(item)
        }
    }

    func save() {
        for item in recentlyAddedItems {
            ContentBlockingManager.shared.radBlockPreferences.add(domain: item.host)
        }
        self.recentlyAddedItems = []
        refreshAllAllowListItems()
    }
}
