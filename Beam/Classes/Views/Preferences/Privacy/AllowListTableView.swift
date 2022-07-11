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
    let searchStr: String
    @Binding var selectedItems: [AllowListViewItem]
    @Binding var creationRowTitle: String?

    @State private var invalidItem: IdentifiableString?

    var allowListColumns = [
        TableViewColumn(key: "host", title: "Sites", editable: true, sortableCaseInsensitive: true, resizable: false, width: 334, fontSize: 12),
        TableViewColumn(key: "addedDate", title: "Date Added", resizable: false, width: 190, fontSize: 12)
    ]

    var body: some View {
        TableView(hasSeparator: false,
                  items: searchStr.isEmpty ? viewModel.allowListItems : filterAllowListItemsBy(searchStr: searchStr),
                  columns: allowListColumns,
                  creationRowTitle: creationRowTitle) { title, index in
            guard let titleStr = title else { return }
            if index < viewModel.allowListItems.count {
                viewModel.update(domain: titleStr, at: index)
            } else {
                viewModel.add(domain: titleStr)
            }
            creationRowTitle = nil

            if !titleStr.validUrl().isValid {
                invalidItem = IdentifiableString(titleStr)
            }
        } onSelectionChanged: { indexes in
            let items = indexes.map { viewModel.allowListItems[$0] }

            DispatchQueue.main.async {
                selectedItems = items
            }
        }
        .alert(item: $invalidItem) { item in
            Alert(title: Text("Invalid URL"),
                  message: Text("'\(item.string)' is not a valid URL and will be discarded if the changes are applied."))
        }
    }

    private func filterAllowListItemsBy(searchStr: String) -> [TableViewItem] {
        return viewModel.allowListItems.filter { item in
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

private struct IdentifiableString: Identifiable {
    let string: String
    var id: String { string }

    init(_ string: String) {
        self.string = string
    }
}
