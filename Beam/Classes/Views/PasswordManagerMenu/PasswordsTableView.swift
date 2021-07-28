//
//  PasswordsTableView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 27/04/2021.
//

import SwiftUI

struct PasswordsTableView: View {
    var passwordEntries: [PasswordManagerEntry]
    var searchStr: String
    @Binding var passwordSelected: Bool
    var onSelectionChanged: (IndexSet) -> Void

    @State private var allPasswordItems = [PasswordTableViewItem]()
    var passwordColumns = [
        TableViewColumn(key: "hostinfo", title: "Sites", type: TableViewColumn.ColumnType.IconAndText, sortable: true, resizable: false, width: 195, fontSize: 11),
        TableViewColumn(key: "username", title: "Username", width: 150, fontSize: 11),
        TableViewColumn(key: "password", title: "Passwords", sortable: false, fontSize: 11)
    ]

    var body: some View {
        TableView(hasSeparator: false, items: searchStr.isEmpty ? allPasswordItems : filterPasswordItemsBy(searchStr: searchStr),
                  columns: passwordColumns, creationRowTitle: nil, shouldReloadData: .constant(nil)) { (_, _) in
        } onSelectionChanged: { idx in
            onSelectionChanged(idx)
            DispatchQueue.main.async {
                passwordSelected = idx.count > 0
            }
        }.onAppear {
            refreshAllPasswordItems()
        }
    }

    private func filterPasswordItemsBy(searchStr: String) -> [PasswordTableViewItem] {
        return allPasswordItems.filter { item in
            item.username.contains(searchStr) || item.host.contains(searchStr)
        }
    }

    private func refreshAllPasswordItems() {
        for entry in passwordEntries {
            let item = PasswordTableViewItem(host: entry.minimizedHost, username: entry.username, password: "••••••••")
            allPasswordItems.append(item)
        }
    }
}

@objcMembers
class PasswordTableViewItem: IconAndTextTableViewItem {
    var username: String
    var password: String
    var host: String

    init(host: String, username: String, password: String) {
        self.username = username
        self.password = password
        self.host = host
        super.init()
        self.favIcon = NSImage(named: "field-web")
        self.text = host
        guard let hostURL = URL(string: "https://\(host)") else { return }
        FaviconProvider.shared.imageForUrl(hostURL) { [weak self] (image) in
            guard let self = self else { return }
            self.favIcon = image
        }

    }
}

struct PasswordsTableView_Previews: PreviewProvider {
    static var previews: some View {
        PasswordsTableView(passwordEntries: [], searchStr: "", passwordSelected: .constant(true), onSelectionChanged: { _ in })
    }
}
