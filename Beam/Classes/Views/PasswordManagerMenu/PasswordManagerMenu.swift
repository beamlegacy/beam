//
//  PasswordManagerMenu.swift
//  Beam
//
//  Created by Frank Lefebvre on 30/03/2021.
//

import SwiftUI
import BeamCore

struct PasswordManagerMenu: View {
    @ObservedObject var viewModel: PasswordManagerMenuViewModel

    @State private var searchString = ""
    @State private var suggestedPassword = ""
    @State private var height: CGFloat?

    var body: some View {
        FormatterViewBackground(boxCornerRadius: 10) {
            VStack(alignment: .leading, spacing: 0) {
                if !viewModel.autofillMenuItems.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(viewModel.autofillMenuItems) { item in
                            menuItemView(item: item) { newState in
                                viewModel.handleStateChange(itemId: item.id, newState: newState)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                ForEach(viewModel.otherMenuItems) { item in
                    menuItemView(item: item) { newState in
                        viewModel.handleStateChange(itemId: item.id, newState: newState)
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
    }

    @ViewBuilder
    func menuItemView(item: PasswordManagerMenuViewModel.MenuItem, onStateChange: @escaping (WebFieldAutofillMenuCellState) -> Void) -> some View {
        let highlightState = viewModel.highlightState(of: item.id)
        switch item {
        case .autofillEntry(let entry):
            StoredPasswordCell(host: viewModel.displayedHost(for: entry), username: entry.username, isHighlighted: highlightState) { newState in
                onStateChange(newState)
                if newState == .clicked {
                    viewModel.fillCredentials(entry)
                }
            }
        case .suggestNewPassword(let passwordGeneratorViewModel):
            PasswordGeneratorSuggestionCell(viewModel: passwordGeneratorViewModel)
        case .showMoreEntriesForHost(let hostname):
            OtherPasswordsCell(host: hostname, isHighlighted: highlightState) { newState in
                onStateChange(newState)
                if newState == .clicked {
                    viewModel.revealMoreItemsForCurrentHost()
                }
            }
        case .showAllPasswords:
            OtherPasswordsCell(isHighlighted: highlightState) { newState in
                onStateChange(newState)
                if newState == .clicked {
                    viewModel.showOtherPasswords()
                }
            }
        case .showSuggestPassword:
            SuggestPasswordCell(isHighlighted: highlightState, onChange: viewModel.onSuggestNewPassword)
        case .separator:
            Separator(horizontal: true)
        }
    }

    private var width: CGFloat {
        if viewModel.suggestNewPassword && viewModel.passwordGeneratorViewModel != nil {
            return 441
        }
        return 255
    }

    private struct HeightKey: FloatPreferenceKey {}
}

struct PasswordManagerMenu_Previews: PreviewProvider {
    static var userInfoStore = MockUserInformationsStore()
    static var previews: some View {
        PasswordManagerMenu(viewModel: PasswordManagerMenuViewModel(host: URL(string: "http://mock1.beam")!, credentialsBuilder: PasswordManagerCredentialsBuilder(passwordManager: PasswordManager(objectManager: BeamObjectManager())), userInfoStore: userInfoStore, options: .login, passwordManager: PasswordManager(objectManager: BeamObjectManager())))
    }
}
