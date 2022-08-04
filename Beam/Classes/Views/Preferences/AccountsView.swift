import SwiftUI
import BeamCore
import OAuthSwift
import Combine

class AccountsViewModel: ObservableObject {
    @ObservedObject var calendarManager: CalendarManager
    @Published var isloggedIn: Bool = AuthenticationManager.shared.isLoggedIn
    @Published var accountsCalendar: [AccountCalendar] = []

    private var scope = Set<AnyCancellable>()

    init(calendarManager: CalendarManager) {
        self.calendarManager = calendarManager
        calendarManager.$connectedSources.sink { [weak self] sources in
            guard let self = self, !sources.isEmpty else {
                self?.accountsCalendar.removeAll()
                return
            }
            for source in sources {
                BeamData.shared.calendarManager.getInformation(for: source) { accountCalendar in
                    if !self.accountsCalendar.contains(where: { $0.sourceId == source.id }) {
                        self.accountsCalendar.append(accountCalendar)
                    }
                }
            }
        }.store(in: &scope)

        AuthenticationManager.shared.isAuthenticatedPublisher.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.isloggedIn = AuthenticationManager.shared.isLoggedIn
        }.store(in: &scope)
    }

    fileprivate func showOnboarding() {
        let onboardingManager = BeamData.shared.onboardingManager
        onboardingManager.showOnboardingForConnectOnly(withConfirmationAlert: false)
    }
}

/// The main view of “Accounts” preference pane.
struct AccountsView: View {
    @State private var enableLogging = true
    @State private var errorMessage: Error!
    @State private var loading = false

    @State private var showingChangeEmailSheet = false
    @State private var showingChangePasswordSheet = false

    @State private var encryptionKeyIsHover = false
    @State private var encryptionKeyIsCopied = false

    @State private var testAccountIsHover = false
    @State private var testAccountIsCopied = false

    @ObservedObject var viewModel: AccountsViewModel

    private let contentWidth: Double = PreferencesManager.contentWidth
    private let checkboxHelper = NSButtonCheckboxHelper()

    var body: some View {
        Settings.Container(contentWidth: PreferencesManager.contentWidth) {
            Settings.Row {
                Text("Account:")
            } content: {
                if viewModel.isloggedIn {
                    accountLoggedInView
                } else {
                    accountLoggedOffView
                }
            }
            Settings.Row {} content: {
                Spacer(minLength: 26).frame(maxHeight: 26)
            }
            calendarSection
            if viewModel.isloggedIn && Persistence.Authentication.email != nil {
                if Configuration.env == .test {
                    Settings.Row(hasDivider: viewModel.isloggedIn) {
                        Text("Test account:")
                    } content: {
                        TestAccountView
                    }
                }
                Settings.Row(hasDivider: viewModel.isloggedIn) {
                    Text("Encryption key:")
                } content: {
                    EncryptionKeyView
                    #if DEBUG
                    RefreshTokenButton
                    #endif
                }
                Settings.Row {
                    Text("Manage:")
                } content: {
                    manageAccountView
                }
            }
        }
    }

    private var calendarSection: Settings.Row {
        Settings.Row(hasDivider: viewModel.isloggedIn) {
            Text("Calendars & Contacts:")
        } content: {
            CalendarContent(viewModel: viewModel)
        }
    }

    // MARK: - Views
    private var accountLoggedInView: some View {
        VStack(alignment: .leading) {
            if let username = AuthenticationManager.shared.username {
                Text(username)
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(height: 16)
            }
            LogoutButton
        }
    }

    private var accountLoggedOffView: some View {
        VStack(alignment: .leading) {
            Button(action: {
                viewModel.showOnboarding()
            }, label: {
                Text("Connect to Beam...")
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(width: 208, height: 20)
                    .padding(.top, -4)
            })
            .padding(.bottom, 6)
            VStack {
                Settings.SubtitleLabel("Sync your notes between device and share them easily.")
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }.frame(width: 238, height: 26, alignment: .leading)
        }
    }

    private var RefreshTokenButton: some View {
        Button(action: {
            self.loading = true
            AuthenticationManager.shared.account?.refreshToken { result in
                self.loading = false
                switch result {
                case .failure(let error):
                    errorMessage = error
                    UserAlert.showError(message: "Error", error: error)
                    Logger.shared.logInfo("Could not refresh token: \(error.localizedDescription)", category: .network)
                case .success(let success):
                    Logger.shared.logInfo("Refresh Token succeeded: \(success)", category: .network)
                }
            }
        }, label: {
            // TODO: loc
            Text("Refresh Token").frame(minWidth: 100)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
        })
        .disabled(!viewModel.isloggedIn)
        .frame(alignment: .leading)
    }

    private var manageAccountView: some View {
        VStack(alignment: .leading) {
            Button(action: {
                promptDeleteAllGraphAlert()
            }, label: {
                // TODO: loc
                Text("Delete Database...")
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(width: 132)
                    .padding(.top, -4)
            })
            Settings.SubtitleLabel("All your notes will be deleted and cannot be recovered.")
                .frame(width: 286, alignment: .leading)
                .padding(.bottom, 20)

            //            Button(action: {
            //                promptDeleteAccountActionAlert()
            //            }, label: {
            //                // TODO: loc
            //                Text("Delete Account...")
            //                    .foregroundColor(BeamColor.Generic.text.swiftUI)
            //                    .frame(width: 132)
            //                    .padding(.top, -4)
            //
            //            })
            //            VStack {
            //                Text("Your account, your database and all your notes will be deleted and cannot be recovered.")
            //                    .lineLimit(2)
            //                    .fixedSize(horizontal: false, vertical: true)
            //                    .multilineTextAlignment(.leading)
            //                    .font(BeamFont.regular(size: 11).swiftUI)
            //                    .foregroundColor(BeamColor.Corduroy.swiftUI)
            //            }.frame(width: 286, height: 26, alignment: .leading)
        }
    }

    private var LogoutButton: some View {
        Button(action: {
            promptLogoutAlert()
        }, label: {
            // TODO: loc
            Text("Sign Out...")
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .frame(width: 146, height: 20, alignment: .center)
                .padding(.top, -4)
        })
    }

    private var EncryptionKeyView: some View {
        VStack(alignment: .leading) {
            Button(action: {
                encryptionKeyIsCopied.toggle()

                EncryptionManager.shared.copyKeyToPasteboard()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    encryptionKeyIsCopied.toggle()
                }
            }, label: {
                HStack {
                    Text(EncryptionManager.shared.privateKey(for: Persistence.emailOrRaiseError()).asString())
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                    Image("preferences-account-copy")
                        .renderingMode(.template)
                        .foregroundColor(encryptionKeyIsHover ? BeamColor.Generic.text.swiftUI : BeamColor.Generic.subtitle.swiftUI)
                        .frame(width: 12, height: 12, alignment: .top)
                }
            }).accessibilityIdentifier("pk-label")
                .buttonStyle(PlainButtonStyle())
                .frame(width: 350, height: 16, alignment: .leading)
                .onHover {
                    encryptionKeyIsHover = $0
                } .overlay(
                    ZStack(alignment: .trailing) {
                        if encryptionKeyIsCopied {
                            Tooltip(title: "Encryption Key Copied!")
                                .fixedSize()
                                .offset(x: 140, y: -25)
                                .transition(Tooltip.defaultTransition)
                        }
                    })

            Settings.SubtitleLabel("Your private key is used to sync your account and decrypt your notes on Beam Web. Click to copy it and paste it on Beam Web.")
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .frame(width: 354, height: 26, alignment: .leading)
                .padding(.bottom, 21)

            Button {
                EncryptionManager.shared.saveKeyToFile(completion: nil)
            } label: {
                Text("Save Private Key...")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
            }.frame(width: 132, height: 20, alignment: .leading)
            Settings.SubtitleLabel("Save your private key as a .beamkey file.")
                .frame(height: 13, alignment: .leading)
        }
    }

    private var TestAccountView: some View {
        VStack(alignment: .leading) {
            Button(action: {
                testAccountIsCopied.toggle()

                copyTestAccountToPasteboard()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    testAccountIsCopied.toggle()
                }
            }, label: {
                HStack {
                    Text(getTestCredentials())
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                    Image("preferences-account-copy")
                        .renderingMode(.template)
                        .foregroundColor(testAccountIsHover ? BeamColor.Generic.text.swiftUI : BeamColor.Generic.subtitle.swiftUI)
                        .frame(width: 12, height: 12, alignment: .top)
                }
            }).accessibilityIdentifier("account-infos")
                .buttonStyle(PlainButtonStyle())
                .frame(width: 350, height: 16, alignment: .center)
                .onHover {
                    testAccountIsHover = $0
                } .overlay(
                    ZStack(alignment: .trailing) {
                        if testAccountIsCopied {
                            Tooltip(title: "Information copied!")
                                .fixedSize()
                                .offset(x: 140, y: -25)
                                .transition(Tooltip.defaultTransition)
                        }
                    })
        }
    }

    fileprivate func getTestCredentials() -> String {
        guard Configuration.env == .test else { return "" }
        guard let username = Persistence.Authentication.username else {
            return ""
        }
        let email = Persistence.emailOrRaiseError()
        let password = Configuration.testAccountPassword
        let privateKey = EncryptionManager.shared.privateKey(for: email).asString()

        return "\(email)\n\(username)\n\(password)\n\(privateKey)"
    }

    fileprivate func copyTestAccountToPasteboard() {
        guard Configuration.env == .test else { return }

        let content = getTestCredentials()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
    }

    private func promptLogoutAlert() {
        let alert = NSAlert()
        alert.messageText = "Are you sure you want to sign out?"
        let customView = NSView(frame: NSRect(x: 0, y: 0, width: 252, height: 16))
        let checkBox = NSButton(checkboxWithTitle: "Delete all data on this device", target: self.checkboxHelper, action: #selector(self.checkboxHelper.checkboxClicked))
        checkBox.state = .on
        self.checkboxHelper.isOn = checkBox.state == .on
        checkBox.frame.origin = CGPoint(x: 0, y: 0)
        checkBox.font = BeamFont.regular(size: 12).nsFont
        customView.addSubview(checkBox)
        checkBox.frame.origin = CGPoint(x: customView.frame.width / 2 - checkBox.fittingSize.width / 2, y: 0)
        alert.accessoryView = customView
        alert.addButton(withTitle: "Sign Out")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard let window = AppDelegate.main.settingsWindowController.window else { return }
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            if self.checkboxHelper.isOn {
                for window in AppDelegate.main.windows {
                    window.state.closeAllTabs(closePinnedTabs: true)
                }
            }
            AuthenticationManager.shared.account?.logout()
            if self.checkboxHelper.isOn {
                AppDelegate.main.deleteAllLocalData()
            }
            viewModel.isloggedIn = AuthenticationManager.shared.isLoggedIn
        }
    }

    // TODO: Implement when endpoint is ready
    private func promptDeleteAllGraphAlert() {
        UserAlert.showMessage(message: "Are you sure you want to delete all your graphs?",
                              informativeText: "All your notes will be deleted and cannot be recovered.",
                              buttonTitle: "Delete",
                              secondaryButtonTitle: "Cancel") {
            AppDelegate.main.deleteDocumentsAndDatabases(includedRemote: true)
        }
    }

    // TODO: Implement when endpoint is ready
    private func promptDeleteAccountActionAlert() {
        UserAlert.showMessage(message: "Are you sure you want to delete your Beam account?",
                              informativeText: "Your account, all your graphs and all your notes will be deleted and cannot be recovered.",
                              buttonTitle: "Delete",
                              secondaryButtonTitle: "Cancel") {
            // TODO: Implement when endpoint is ready
        }
    }
}

struct AccountsView_Previews: PreviewProvider {
    static var previews: some View {
        AccountsView(viewModel: AccountsViewModel(calendarManager: BeamData.shared.calendarManager))
    }
    // swiftlint:disable:next file_length
}
