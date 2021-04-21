//
//  PasswordManagerMenu.swift
//  Beam
//
//  Created by Frank Lefebvre on 30/03/2021.
//

import SwiftUI
import BeamCore

struct HeightKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
}

struct PasswordManagerMenu: View {
    let width: CGFloat
    @ObservedObject var viewModel: PasswordManagerMenuViewModel

    @State private var searchString: String = ""
    @State private var suggestedPassword: String = ""

    @State private var height: CGFloat?

    var body: some View {
        OmniBarFieldBackground(isEditing: true, alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                if let passwordGeneratorViewModel = viewModel.passwordGeneratorViewModel {
                    PasswordGeneratorCellGroup(viewModel: passwordGeneratorViewModel)
                }
                if viewModel.display.searchCell == .field {
                    // TODO: use closure for macOS 10.15
                    if #available(macOS 11.0, *) {
                        SearchPasswordsCell(active: true, searchString: $searchString)
                            .onChange(of: searchString, perform: { value in
                                self.viewModel.updateSearchString(value)
                            })
                    }
                    if viewModel.display.showSearchSeparator {
                        Separator(horizontal: true)
                    }
                }
                if viewModel.display.hasScroll {
                    ScrollView {
                        ForEach(viewModel.display.entries) { entry in
                            StoredPasswordCell(host: entry.host, username: entry.username, searchString: viewModel.display.searchCell == .field ? searchString : nil) { newState in
                                if newState == .clicked {
                                    viewModel.fillCredentials(entry)
                                }
                            }
                        }
                    }
                    .frame(height: 244) // TODO: use preference key
                } else {
                    ForEach(viewModel.display.entries) { entry in
                        StoredPasswordCell(host: entry.host, username: entry.username, searchString: viewModel.display.searchCell == .field ? searchString : nil) { newState in
                            if newState == .clicked {
                                viewModel.fillCredentials(entry)
                            }
                        }
                    }
                    if viewModel.display.moreEntries > 0 {
                        PasswordsViewMoreCell(count: viewModel.display.moreEntries) { newState in
                            if newState == .clicked {
                                self.viewModel.revealAdditionalItems()
                            }
                        }
                    }
                }
                if viewModel.display.searchCell == .button {
                    if viewModel.display.showSearchSeparator {
                        Separator(horizontal: true)
                    }
                    SearchPasswordsCell(active: false, searchString: .constant("")) { newState in
                        if newState == .clicked {
                            self.viewModel.startSearch()
                        }
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .background(GeometryReader { proxy in
                Color.clear.preference(key: HeightKey.self, value: proxy.size.height)
            })
            .onPreferenceChange(HeightKey.self) {
                self.height = $0
            }.animation(nil)
        }
        .frame(width: max(width, 400), height: height, alignment: .top)
        .animation(nil)
    }
}

struct PasswordManagerMenu_Previews: PreviewProvider {
    static var previews: some View {
        Text("Hello World")
//        PasswordManagerMenu()
    }
}
