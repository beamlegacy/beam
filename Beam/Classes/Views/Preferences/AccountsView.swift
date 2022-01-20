import SwiftUI
import Preferences
import BeamCore
import OAuthSwift
import Combine

let AccountsPreferenceViewController: PreferencePane = PreferencesPaneBuilder.build(identifier: .accounts, title: "Account", imageName: "preferences-account") {
    AccountsView(viewModel: AccountsViewModel(calendarManager: AppDelegate.main.data.calendarManager))
}

class AccountsViewModel: ObservableObject {
    @ObservedObject var calendarManager: CalendarManager
    @Published var isloggedIn: Bool = AuthenticationManager.shared.isAuthenticated
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
                AppDelegate.main.data.calendarManager.getInformation(for: source) { accountCalendar in
                    if !self.accountsCalendar.contains(where: { $0.sourceId == source.id }) {
                        self.accountsCalendar.append(accountCalendar)
                    }
                }
            }
        }.store(in: &scope)

        AuthenticationManager.shared.isAuthenticatedPublisher.receive(on: DispatchQueue.main).sink { [weak self] isAuthenticated in
            self?.isloggedIn = isAuthenticated
        }.store(in: &scope)
    }

    fileprivate func showOnboarding() {
        let onboardingManager = AppDelegate.main.data.onboardingManager
        onboardingManager.prepareForConnectOnly()
        onboardingManager.presentOnboardingWindow()
    }
}

/*
The main view of “Accounts” preference pane.
*/
// swiftlint:disable:next type_body_length
struct AccountsView: View {
    @State private var enableLogging: Bool = true
    @State private var errorMessage: Error!
    @State private var loading: Bool = false

    @State private var showingChangeEmailSheet: Bool = false
    @State private var showingChangePasswordSheet: Bool = false

    @State var encryptionKeyIsHover = false
    @State var encryptionKeyIsCopied = false

    @ObservedObject var viewModel: AccountsViewModel

    let transition = AnyTransition.asymmetric(insertion: AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.2)),
                                              removal: AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.08)))

    private let accountManager = AccountManager()
    private let contentWidth: Double = PreferencesManager.contentWidth
    private let checkboxHelper = NSButtonCheckboxHelper()

	var body: some View {
        Preferences.Container(contentWidth: contentWidth) {
            Preferences.Section(bottomDivider: false, verticalAlignment: .top) {
                Text("Account:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(width: 250, alignment: .trailing)
            } content: {
                if viewModel.isloggedIn {
                    accountLoggedInView
                } else {
                    accountLoggedOffView
                }
            }
            Preferences.Section(title: "") {
                Spacer(minLength: 26).frame(maxHeight: 26)
            }
            Preferences.Section(bottomDivider: viewModel.isloggedIn, verticalAlignment: .top) {
                Text("Calendars & Contacts:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(width: 250, alignment: .trailing)
            } content: {
                VStack(alignment: .leading) {
                    if viewModel.accountsCalendar.isEmpty {
                        connectGoogleCalendarView
                    } else {
                        VStack(alignment: .leading) {
                            VStack(alignment: .leading) {
                                ForEach(viewModel.accountsCalendar) { account in
                                    GoogleAccountView(viewModel: viewModel, account: account) {
                                        viewModel.calendarManager.disconnect(from: .googleCalendar, sourceId: account.sourceId)
                                        viewModel.accountsCalendar.removeAll(where: { $0 === account })
                                    }
                                }
                            }.padding(.bottom, 20)

                            Button(action: {
                                viewModel.calendarManager.requestAccess(from: .googleCalendar) { connected in
                                    if connected { viewModel.calendarManager.updated = true }
                                }
                            }, label: {
                                // TODO: loc
                                Text("Connect Another Google Calendar...")
                                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                                    .frame(width: 236)
                                    .padding(.top, -4)
                            })
                            VStack {
                                Text("Connect with Google to import your Calendar & Contacts and easily take meeting notes.")
                                    .font(BeamFont.regular(size: 11).swiftUI)
                                    .foregroundColor(BeamColor.Corduroy.swiftUI)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                            }.frame(width: 297, height: 26, alignment: .leading)
                        }
                    }
                }
            }

            Preferences.Section(bottomDivider: viewModel.isloggedIn, verticalAlignment: .firstTextBaseline) {
                Text("Encryption key:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(width: 250, alignment: .trailing)
                    .if(!viewModel.isloggedIn) { view in
                        view.hidden()
                    }
            } content: {
                if viewModel.isloggedIn {
                    EncryptionKeyView
                    #if DEBUG
                    RefreshTokenButton
                    #endif
                }
            }

            Preferences.Section(bottomDivider: false, verticalAlignment: .firstTextBaseline) {
                Text("Manage:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(width: 250, alignment: .trailing)
                    .if(!viewModel.isloggedIn) { view in
                        view.hidden()
                    }
            } content: {
                if viewModel.isloggedIn {
                    manageAccountView
                }
            }
        }
	}

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
                Text("Sync your notes between device and share them easily")
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .font(BeamFont.regular(size: 11).swiftUI)
                    .foregroundColor(BeamColor.Corduroy.swiftUI)
            }.frame(width: 238, height: 26, alignment: .leading)
        }
    }

    private var connectGoogleCalendarView: some View {
        VStack(alignment: .leading) {
            Button(action: {
                viewModel.calendarManager.requestAccess(from: .googleCalendar) { connected in
                    if connected { viewModel.calendarManager.updated = true }
                }
            }, label: {
                // TODO: loc
                Text("Connect Google Calendar...")
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(width: 208)
                    .padding(.top, -4)
            })
        }
    }

    private var RefreshTokenButton: some View {
        Button(action: {
            self.loading = true
            accountManager.refreshToken { result in
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
            Text("All your notes will be deleted and cannot be recovered.")
                .font(BeamFont.regular(size: 11).swiftUI)
                .foregroundColor(BeamColor.Corduroy.swiftUI)
                .frame(width: 286, alignment: .leading)
                .padding(.bottom, 20)

            Button(action: {
                promptDeleteAccountActionAlert()
            }, label: {
                // TODO: loc
                Text("Delete Account...")
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(width: 132)
                    .padding(.top, -4)

            })
            VStack {
                Text("Your account, your database and all your notes will be deleted and cannot be recovered.")
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .font(BeamFont.regular(size: 11).swiftUI)
                    .foregroundColor(BeamColor.Corduroy.swiftUI)
            }.frame(width: 286, height: 26, alignment: .leading)
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

                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(EncryptionManager.shared.privateKey().asString(), forType: .string)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    encryptionKeyIsCopied.toggle()
                }
            }, label: {
                HStack {
                    Text(EncryptionManager.shared.privateKey().asString())
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                    Image("preferences-account-copy")
                        .renderingMode(.template)
                        .foregroundColor(encryptionKeyIsHover ? BeamColor.Generic.text.swiftUI : BeamColor.Generic.subtitle.swiftUI)
                        .frame(width: 12, height: 12, alignment: .top)
                }
            }).buttonStyle(PlainButtonStyle())
                .frame(width: 350, height: 16, alignment: .center)
                .onHover {
                    encryptionKeyIsHover = $0
                } .overlay(
                    ZStack(alignment: .trailing) {
                        if encryptionKeyIsCopied {
                            Tooltip(title: "Encryption Key Copied !")
                                .fixedSize()
                                .offset(x: 140, y: -25)
                                .transition(transition)
                        }
                    })

            Text("Your encryption key is used to decrypt your notes on Beam Web. Click to copy it and paste it on Beam Web.")
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .font(BeamFont.regular(size: 11).swiftUI)
                .foregroundColor(BeamColor.Corduroy.swiftUI)
                .frame(width: 354, height: 26, alignment: .leading)
        }
    }

    private func promptLogoutAlert() {
        let alert = NSAlert()
        alert.messageText = "Are you sure you want to sign out ?"
        let customView = NSView(frame: NSRect(x: 0, y: 0, width: 252, height: 16))
        let checkBox = NSButton(checkboxWithTitle: "Delete all data on this device", target: self.checkboxHelper, action: #selector(self.checkboxHelper.checkboxClicked))
        checkBox.frame.origin = CGPoint(x: 0, y: 0)
        checkBox.font = BeamFont.regular(size: 12).nsFont
        customView.addSubview(checkBox)
        checkBox.frame.origin = CGPoint(x: customView.frame.width / 2 - checkBox.fittingSize.width / 2, y: 0)
        alert.accessoryView = customView
        alert.addButton(withTitle: "Sign Out")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard let window = AccountsPreferenceViewController.view.window else { return }
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            AccountManager.logout()
            if self.checkboxHelper.isOn {
                AppDelegate.main.deleteAllLocalContent()
            }
            viewModel.isloggedIn = AuthenticationManager.shared.isAuthenticated
        }
    }

    // TODO: Implement when endpoint is ready
    private func promptDeleteAllGraphAlert() {
        UserAlert.showMessage(message: "Are you sure you want to delete all your graphs?",
                              informativeText: "All your notes will be deleted and cannot be recovered.",
                              buttonTitle: "Delete",
                              secondaryButtonTitle: "Cancel") {
            // TODO: Implement when endpoint is ready
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

struct GoogleAccountView: View {
    @ObservedObject var viewModel: AccountsViewModel
    var account: AccountCalendar
    var onDisconnect: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(account.name)
                    .frame(width: 227, alignment: .leading)
                    .padding(.trailing, 12)
                if viewModel.calendarManager.connectedSources.first(where: { $0.id == account.sourceId })?.inNeedOfPermission ?? true {
                    Button {
                        onDisconnect?()
                        viewModel.calendarManager.requestAccess(from: .googleCalendar) { connected in
                            if connected { viewModel.calendarManager.updated = true }
                        }
                    } label: {
                        Text("Fix Permissions...")
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                            .frame(width: 125)
                            .padding(.top, -4)
                    }
                } else {
                    Button {
                        UserAlert.showMessage(message: "Are you sure you want to disconnect your Google account?",
                                              informativeText: "You’ll need to add it again to sync your Google Calendars and Contacts.",
                                              buttonTitle: "Disconnect",
                                              secondaryButtonTitle: "Cancel") {
                            onDisconnect?()
                        }
                    } label: {
                        Text("Disconnect")
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                            .frame(width: 99)
                            .padding(.top, -4)
                    }
                }
            }.padding(.bottom, -5)
            if viewModel.calendarManager.connectedSources.first(where: { $0.id == account.sourceId })?.inNeedOfPermission ?? true {
                Text("Fix permissions to sync...")
                    .font(BeamFont.regular(size: 11).swiftUI)
                    .foregroundColor(BeamColor.Shiraz.swiftUI)
            } else {
                Text("\(account.nbrOfCalendar) calendars, 0 contacts synced")
                    .font(BeamFont.regular(size: 11).swiftUI)
                    .foregroundColor(BeamColor.Corduroy.swiftUI)
            }

        }
    }
}

struct AccountsView_Previews: PreviewProvider {
    static var previews: some View {
        AccountsView(viewModel: AccountsViewModel(calendarManager: AppDelegate.main.data.calendarManager))
    }
    // swiftlint:disable:next file_length
}
