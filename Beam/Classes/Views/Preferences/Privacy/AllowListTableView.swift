//
//  AllowListTableView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 07/06/2021.
//

import SwiftUI
import BeamCore

struct AllowListTableView: View {
    @ObservedObject var viewModel: AllowListViewModel
    var searchStr: String
    @Binding var selectedItems: [RBAllowlistEntry]
    @Binding var creationRowTitle: String?

    var allowListColumns = [
        TableViewColumn(key: "host", title: "Sites", editable: true, sortableCaseInsensitive: true, resizable: false, width: 334, fontSize: 12),
        TableViewColumn(key: "addedDate", title: "Date Added", resizable: false, width: 190, fontSize: 12)
    ]

    var body: some View {
        TableView(hasSeparator: false,
                  items: searchStr.isEmpty ? viewModel.allAllowListItems : filterAllowListItemsBy(searchStr: searchStr),
                  columns: allowListColumns,
                  creationRowTitle: creationRowTitle) { title, _ in
            guard let titleStr = title else { return }
            viewModel.add(domain: titleStr)
            creationRowTitle = nil
        } onSelectionChanged: { indexes in
            var newSelectedItems: [RBAllowlistEntry] = []
            for idx in indexes {
                guard let entry = viewModel.allAllowListItems[idx].entry else { continue }
                newSelectedItems.append(entry)
            }
            DispatchQueue.main.async {
                selectedItems = newSelectedItems
            }
        }
    }

    private func filterAllowListItemsBy(searchStr: String) -> [TableViewItem] {
        return viewModel.allAllowListItems.filter { item in
            item.host.contains(searchStr)
        }
    }
}

@objcMembers
class AllowListViewItem: TableViewItem {
    var entry: RBAllowlistEntry?
    var host: String
    var addedDate: String

    init(entry: RBAllowlistEntry) {
        self.entry = entry
        self.host = entry.domain
        let dateFormatter = DateFormatter()
        dateFormatter.doesRelativeDateFormatting = true
        dateFormatter.dateStyle = .long
        self.addedDate = dateFormatter.string(from: entry.dateCreated)
        super.init()
    }

    init(domain: String) {
        self.host = domain
        let dateFormatter = DateFormatter()
        dateFormatter.doesRelativeDateFormatting = true
        dateFormatter.dateStyle = .long
        self.addedDate = dateFormatter.string(from: BeamDate.now)
        super.init()
    }
}
