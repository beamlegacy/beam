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

    @State private var searchString = ""
    @State private var suggestedPassword = ""
    @State private var showingOtherPasswordsSheet = false
    @State private var height: CGFloat?

    var body: some View {
        FormatterViewBackground {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.display.suggestNewPassword, let passwordGeneratorViewModel = viewModel.passwordGeneratorViewModel {
                    PasswordGeneratorSuggestionCell(viewModel: passwordGeneratorViewModel)
                        .frame(height: 81, alignment: .center)
                } else {
                    ForEach(viewModel.display.entriesForHost.prefix(3)) { entry in
                        StoredPasswordCell(host: entry.minimizedHost, username: entry.username) { newState in
                            if newState == .clicked {
                                viewModel.fillCredentials(entry)
                            }
                        }
                    }
                    if viewModel.display.entriesForHost.count == 1 && viewModel.display.hasMoreThanOneEntry {
                        Separator(horizontal: true)
                            .padding(.vertical, 1)
                            .padding(.horizontal, 12)
                        PasswordsViewMoreCell(hostName: viewModel.getHostStr()) { newState in
                            if newState == .clicked {
                                viewModel.revealMoreItemsForCurrentHost()
                            }
                        }
                    }
                    if viewModel.display.entriesForHost.count > 1 {
                        Separator(horizontal: true)
                            .padding(.vertical, 1)
                            .padding(.horizontal, 12)
                    }
                    if viewModel.display.entriesForHost.count != 1 || !viewModel.display.hasMoreThanOneEntry {
                        OtherPasswordsCell { newState in
                            // Show More Password view
                            if newState == .clicked {
                                viewModel.revealAllItems()
                                showingOtherPasswordsSheet.toggle()
                            }
                        }.sheet(isPresented: $showingOtherPasswordsSheet, content: {
                            OtherPasswordModal(viewModel: viewModel.otherPasswordsViewModel, onFill: { entry in
                                viewModel.fillCredentials(entry)
                            }, onRemove: { entry in
                                viewModel.deleteCredentials(entry)
                            }, onDismiss: {
                                showingOtherPasswordsSheet.toggle()
                                viewModel.resetItems()
                            }).frame(width: 568, height: 361, alignment: .center)
                        })
                    }
                    if viewModel.display.showSuggestPasswordOption {
                        Separator(horizontal: true)
                            .padding(.vertical, 1)
                            .padding(.horizontal, 12)
                        SuggestPasswordCell(onChange: viewModel.onSuggestNewPassword)
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
        .animation(nil)
    }
}

struct PasswordManagerMenu_Previews: PreviewProvider {
    static var userInfoStore = MockUserInformationsStore()
    static var previews: some View {
        PasswordManagerMenu(width: 300, viewModel: PasswordManagerMenuViewModel(host: URL(string: "http://mock1.beam")!, credentialsBuilder: PasswordManagerCredentialsBuilder(), userInfoStore: userInfoStore, options: .login))
    }
}
