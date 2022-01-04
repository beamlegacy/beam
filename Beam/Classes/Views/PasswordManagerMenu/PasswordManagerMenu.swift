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
    @ObservedObject var viewModel: PasswordManagerMenuViewModel

    @State private var searchString = ""
    @State private var suggestedPassword = ""
    @State private var showingOtherPasswordsSheet = false
    @State private var height: CGFloat?

    var body: some View {
        FormatterViewBackground(boxCornerRadius: 10) {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.display.suggestNewPassword, let passwordGeneratorViewModel = viewModel.passwordGeneratorViewModel {
                    PasswordGeneratorSuggestionCell(viewModel: passwordGeneratorViewModel)
                } else {
                    if !viewModel.display.entriesForHost.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(viewModel.display.entriesForHost.prefix(viewModel.display.entryDisplayLimit)) { entry in
                                StoredPasswordCell(host: entry.minimizedHost, username: entry.username) { newState in
                                    if newState == .clicked {
                                        viewModel.fillCredentials(entry)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        Separator(horizontal: true)
                    }
                    if viewModel.display.entriesForHost.count <= 1 || viewModel.display.entryDisplayLimit > 1 {
                        OtherPasswordsCell { newState in
                            if newState == .clicked {
                                showingOtherPasswordsSheet.toggle()
                            }
                        }
                    } else {
                        OtherPasswordsCell(host: viewModel.host.minimizedHost) { newState in
                            if newState == .clicked {
                                viewModel.revealMoreItemsForCurrentHost()
                            }
                        }
                    }
                    if viewModel.display.showSuggestPasswordOption {
                        Separator(horizontal: true)
                        SuggestPasswordCell(onChange: viewModel.onSuggestNewPassword)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .background(GeometryReader { proxy in
                BeamColor.WebFieldAutofill.popupBackground.swiftUI
                    .preference(key: HeightKey.self, value: proxy.size.height)
            })
            .onPreferenceChange(HeightKey.self) {
                self.height = $0
            }
            .animation(nil)
        }
        .frame(width: width, height: height, alignment: .top)
        .animation(nil)
        .sheet(isPresented: $showingOtherPasswordsSheet, content: {
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

    var width: CGFloat {
        if viewModel.display.suggestNewPassword && viewModel.passwordGeneratorViewModel != nil {
            return 441
        }
        return 255
    }
}

struct PasswordManagerMenu_Previews: PreviewProvider {
    static var userInfoStore = MockUserInformationsStore()
    static var previews: some View {
        PasswordManagerMenu(viewModel: PasswordManagerMenuViewModel(host: URL(string: "http://mock1.beam")!, credentialsBuilder: PasswordManagerCredentialsBuilder(), userInfoStore: userInfoStore, options: .login))
    }
}
