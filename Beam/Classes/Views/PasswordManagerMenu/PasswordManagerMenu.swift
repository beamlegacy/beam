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
    @State private var showingOtherPasswordsSheet = false
    @State private var height: CGFloat?

    @State private var isShowingToast: Bool = false

    var body: some View {
        FormatterViewBackground(shadowOpacity: 0.1) {
            VStack(alignment: .leading, spacing: 0) {
                if let passwordGeneratorViewModel = viewModel.passwordGeneratorViewModel {
                    PasswordGeneratorCellGroup(viewModel: passwordGeneratorViewModel)
                } else {
                    ForEach(viewModel.display.entries.prefix(3)) { entry in
                        StoredPasswordCell(host: entry.host, username: entry.username) { newState in
                            if newState == .clicked {
                                viewModel.fillCredentials(entry)
                            }
                        }
                    }
                    if viewModel.display.entries.count == 1 && viewModel.display.hasMoreThanOneEntry {
                        Separator(horizontal: true)
                            .padding(.vertical, 1)
                            .padding(.horizontal, 12)
                        PasswordsViewMoreCell(hostName: viewModel.getHostStr()) { newState in
                            if newState == .clicked {
                                viewModel.revealMoreItems()
                            }
                        }
                    }
                    if viewModel.display.entries.count > 1 {
                        Separator(horizontal: true)
                            .padding(.vertical, 1)
                            .padding(.horizontal, 12)
                        OtherPasswordsCell { newState in
                            // Show More Password view
                            if newState == .clicked {
                                viewModel.revealAllItems()
                                showingOtherPasswordsSheet.toggle()
                            }
                        }.sheet(isPresented: $showingOtherPasswordsSheet, content: {
                            OtherPasswordModal(passwordEntries: viewModel.display.entries, onFill: { entry in
                                viewModel.fillCredentials(entry)
                            }, onRemove: { entry in
                                // TODO: Implement when password will be saved
                                viewModel.removeCredentials(entry)
                            }, onDismiss: {
                                showingOtherPasswordsSheet.toggle()
                                viewModel.resetItems()
                            }).frame(width: 568, height: 361, alignment: .center)
                        })
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
        .cornerRadius(6)
        .shadow(color: Color.black.opacity(0.1), radius: 24, x: 0, y: 4)
        .animation(nil)
    }
}

struct PasswordManagerMenu_Previews: PreviewProvider {
    static var previews: some View {
        Text("Hello World")
//        PasswordManagerMenu()
    }
}
