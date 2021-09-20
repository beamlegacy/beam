//
//  PasswordsTableView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 27/04/2021.
//

import SwiftUI

struct PasswordsTableView: View {
    var passwordEntries: [PasswordTableViewItem]
    var onSelectionChanged: (IndexSet) -> Void // identifiable --> use id somewhere

    static let passwordColumns = [
        TableViewColumn(key: "hostname", title: "Sites", type: TableViewColumn.ColumnType.IconAndText,
                        sortableCaseInsensitive: true, resizable: false, width: 195, fontSize: 11),
        TableViewColumn(key: "username", title: "Username", sortableCaseInsensitive: true, width: 150, fontSize: 11),
        TableViewColumn(key: "password", title: "Passwords", sortable: false, fontSize: 11)
    ]

    var body: some View {
        TableView(hasSeparator: false, items: passwordEntries,
                  columns: Self.passwordColumns, creationRowTitle: nil, shouldReloadData: .constant(nil)) { (_, _) in
        } onSelectionChanged: { idx in
            onSelectionChanged(idx)
        }
    }
}

@objcMembers
class PasswordTableViewItem: IconAndTextTableViewItem {
    var username: String
    var password: String
    var hostname: String

    init(hostname: String, username: String, password: String) {
        self.username = username
        self.password = password
        self.hostname = hostname
        super.init()
        self.favIcon = NSImage(named: "field-web")
        self.text = hostname
        guard let hostURL = URL(string: "https://\(hostname)") else { return }
        FaviconProvider.shared.imageForUrl(hostURL) { [weak self] (image) in
            guard let self = self else { return }
            self.favIcon = image // TODO: refresh table view
        }
    }
}

extension PasswordTableViewItem {
    convenience init(_ entry: PasswordManagerEntry) {
        self.init(hostname: entry.minimizedHost, username: entry.username, password: "••••••••")
    }
}

struct PasswordsTableView_Previews: PreviewProvider {
    static var previews: some View {
        PasswordsTableView(passwordEntries: [], onSelectionChanged: { _ in })
    }
}
