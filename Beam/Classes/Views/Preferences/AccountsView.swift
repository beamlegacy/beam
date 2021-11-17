import SwiftUI
import Preferences
import BeamCore
import OAuthSwift

let AccountsPreferenceViewController: PreferencePane = PreferencesPaneBuilder.build(identifier: .accounts, title: "Account", imageName: "preferences-account") {
    AccountsView(googleCalendarNeedsPermission: AppDelegate.main.data.calendarManager.connectedSources.first(where: {$0.name == CalendarServices.googleCalendar.rawValue})?.inNeedOfPermission ?? true)
}

/*
The main view of “Accounts” preference pane.
*/

// swiftlint:disable:next type_body_length
struct AccountsView: View {
    #if DEBUG
    @State private var email: String = Persistence.Authentication.email ?? ""
    @State private var password: String = Persistence.Authentication.password ?? ""
    #else
    @State private var email: String = Persistence.Authentication.email ?? ""
    @State private var password: String = ""
    #endif
    @State private var enableLogging: Bool = true
    @State private var loggedIn: Bool = AccountManager().loggedIn
    @State private var errorMessage: Error!
    @State private var loading: Bool = false
    @State private var identities: [IdentityType] = []
    @State var googleCalendarNeedsPermission: Bool

    @State private var showingChangeEmailSheet: Bool = false
    @State private var showingChangePasswordSheet: Bool = false

    @State var encryptionKeyIsHover = false
    @State var encryptionKeyIsCopied = false

    let transition = AnyTransition.asymmetric(insertion: AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.2)),
                                              removal: AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.08)))

    private let accountManager = AccountManager()
    private let contentWidth: Double = PreferencesManager.contentWidth

	var body: some View {
        Preferences.Container(contentWidth: contentWidth) {
            Preferences.Section {
                Text("Account:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(width: 250, alignment: .trailing)
            } content: {
                if loggedIn {
                    VStack(alignment: .leading) {
                        // TODO: This need to be changed later on for the username
                        Text(email)
                            .font(BeamFont.regular(size: 13).swiftUI)
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                            .frame(height: 16)
                        Text(email)
                            .font(BeamFont.regular(size: 11).swiftUI)
                            .foregroundColor(BeamColor.Corduroy.swiftUI)
                            .frame(height: 13)

                        LogoutButton
                            .padding(.bottom, 5)

                        EncryptionKeyView
                        #if DEBUG
                        RefreshTokenButton
                        #endif
                    }
                } else {
                    VStack(alignment: .leading) {
                        AccountCredentialsView(email: $email,
                                               password: $password,
                                               loggedIn: $loggedIn,
                                               loading: $loading)
                        HStack(spacing: 10) {
                            SignUpButton
                            SignInButton
                        }
                        VStack(alignment: .leading) {
                            GoogleSignInButton
                            GithubSignInButton
                        }
                    }
                    VStack {
                        Text("Join Beam to publish your cards and sync your graphs between your devices")
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                            .font(BeamFont.regular(size: 11).swiftUI)
                            .foregroundColor(BeamColor.Corduroy.swiftUI)
                    }.frame(width: 211, height: 26, alignment: .leading)
                }
            }
        }.onAppear(perform: {
            self.fetchIdentities()

            // Fetch Safari credentials if not already logged in
            guard !self.loggedIn else { return }

            /*
             This is not implemented due to Apple limitations
            accountManager.fetchSafariCredentials { (username, password) in
                if let username = username, !username.isEmpty { self.email = username }
                if let password = password, !password.isEmpty { self.password = password }
            }
             */
        })
        if loggedIn {
            Preferences.Container(contentWidth: contentWidth) {
                Preferences.Section(bottomDivider: true) {
                    Text("Connect:")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                        .frame(width: 250, alignment: .trailing)
                } content: {
                    VStack(alignment: .leading) {
                        if let googleIdendity = identities.first(where: {$0.provider == "google"}) {
                            HStack {
                                disconnectButton(googleIdendity)
                                if googleCalendarNeedsPermission {
                                    AskGooglePermission
                                }
                            }
                            if googleCalendarNeedsPermission {
                                Text("Click on the Give Permissions button to give Beam access to your Google Calendar & Contacts.")
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                                    .font(BeamFont.regular(size: 11).swiftUI)
                                    .foregroundColor(BeamColor.Corduroy.swiftUI)
                                    .frame(width: 354, height: 26, alignment: .leading)
                            }
                        } else {
                            GoogleSignInButton
                        }
                        if let githubIdendity = identities.first(where: {$0.provider == "github"}) {
                            disconnectButton(githubIdendity)
                        } else {
                            GithubSignInButton
                        }
                    }
                }
                Preferences.Section(bottomDivider: false) {
                    Text("Manage:")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                        .frame(width: 250, alignment: .trailing)
                } content: {
                    VStack(alignment: .leading) {
                        Button(action: {
                            showingChangeEmailSheet.toggle()
                        }, label: {
                            // TODO: loc
                            Text("Change Email Address...")
                                .foregroundColor(BeamColor.Generic.text.swiftUI)
                                .frame(width: 148)
                        }).sheet(isPresented: $showingChangeEmailSheet) {
                            ChangeCredentialsView(changeCredentialsType: .email)
                                .frame(width: 485, height: 151, alignment: .center)
                        }
                        Button(action: {
                            showingChangePasswordSheet.toggle()
                        }, label: {
                            // TODO: loc
                            Text("Change Password...")
                                .foregroundColor(BeamColor.Generic.text.swiftUI)
                                .frame(width: 121)
                        }).sheet(isPresented: $showingChangePasswordSheet) {
                            ChangeCredentialsView(changeCredentialsType: .password)
                                .frame(width: 485, height: 198, alignment: .center)
                        }
                    }.padding(.bottom, 20)

                    VStack(alignment: .leading) {
                        Button(action: {
                            promptDeleteAllGraphAlert()
                        }, label: {
                            // TODO: loc
                            Text("Delete All Graphs...")
                                .foregroundColor(BeamColor.Generic.text.swiftUI)
                                .frame(width: 116)
                        })
                        Text("All your cards will be deleted and cannot be recovered.")
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
                                .frame(width: 105)
                        })
                        VStack {
                            Text("Your account, all your graphs and all your cards will be deleted and cannot be recovered.")
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                                .font(BeamFont.regular(size: 11).swiftUI)
                                .foregroundColor(BeamColor.Corduroy.swiftUI)
                        }.frame(width: 286, height: 26, alignment: .leading)
                    }
                }
            }
        }
	}

    @State private var showingSignUpAlert = false
    private var SignUpButton: some View {
        Button(action: {
            self.loading = true
            accountManager.signUp(email, password) { result in
                self.loading = false
                switch result {
                case .failure(let error):
                    errorMessage = error
                    showingSignUpAlert = true
                    Logger.shared.logInfo("Could not sign up: \(error.localizedDescription)", category: .network)
                case .success:
                    Logger.shared.logInfo("signUp succeeded", category: .network)
                    self.fetchIdentities()
                }
            }
        }, label: {
            // TODO: loc
            Text("Sign Up...")
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .frame(width: 63)
        })
        .disabled(loggedIn || loading || email.isEmpty || password.isEmpty)
        .alert(isPresented: $showingSignUpAlert) {
            Alert(title: Text("Error"),
                  message: Text(errorMessage.localizedDescription))
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
                    showingSignInAlert = true
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
        .disabled(!loggedIn)
        .alert(isPresented: $showingSignInAlert) {
            Alert(title: Text("Error"), message: Text(errorMessage.localizedDescription))
        }
    }

    @State private var showingSignInAlert = false
    private var SignInButton: some View {
        Button(action: {
            self.loading = true
            accountManager.signIn(email, password) { result in
                self.loading = false
                loggedIn = AccountManager().loggedIn
                switch result {
                case .failure(let error):
                    errorMessage = error
                    showingSignInAlert = true
                    Logger.shared.logInfo("Could not sign in: \(error.localizedDescription)", category: .network)
                case .success:
                    Logger.shared.logInfo("sign in succeeded", category: .network)
                    self.fetchIdentities()
                }
            }
        }, label: {
            // TODO: loc
            Text("Sign In...")
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .frame(width: 56)
        })
        .disabled(loggedIn || loading || email.isEmpty || password.isEmpty)
        .alert(isPresented: $showingSignInAlert) {
            #if DEBUG
            Alert(title: Text("Error"),
                  message: Text("Invalid password or email with: \(errorMessage.localizedDescription)"))
            #else
            Alert(title: Text("Error"),
                  message: Text("Invalid password or email"))
            #endif
        }
    }

    private var GoogleSignInButton: some View {
        GoogleButton(buttonType: loggedIn ? .connect : .signin, onClick: {
            loading = true
        }, onConnect: {
            loggedIn = AccountManager().loggedIn
            fetchIdentities()
            loading = false
            AppDelegate.main.data.calendarManager.connect(calendarService: .googleCalendar)
        }, onFailure: {
            loading = false
        }).disabled(loading)
    }

    private var AskGooglePermission: some View {
        Button {
            AppDelegate.main.data.calendarManager.requestAccess(from: .googleCalendar) { isConnected in
                // TODO: Handle error with alert maybe
                googleCalendarNeedsPermission = !isConnected
            }
        } label: {
            Text("Give Permissions...")
        }
    }

    private var GithubSignInButton: some View {
        GithubButton(buttonType: loggedIn ? .connect : .signin, onClick: {
            loading = true
        }, onConnect: {
            loggedIn = AccountManager().loggedIn
            fetchIdentities()
            loading = false
        }, onFailure: {
            loading = false
        }).disabled(loading)
    }

    @State private var showingForgotPasswordAlert = false
    private var ForgotPasswordButton: some View {
        Button(action: {
            self.loading = true
            accountManager.forgotPassword(email: email) { result in
                self.loading = false
                switch result {
                case .failure(let error):
                    errorMessage = error
                    showingForgotPasswordAlert = true
                    Logger.shared.logInfo("Could not forgot password: \(error.localizedDescription)", category: .network)
                case .success:
                    Logger.shared.logInfo("forgot Password succeeded", category: .network)
                }
            }
        }, label: {
            // TODO: loc
            Text("Forgot Password").frame(minWidth: 100)
        })
        .disabled(loggedIn || loading || email.isEmpty)
        .alert(isPresented: $showingForgotPasswordAlert) {
            Alert(title: Text("Error"),
                  message: Text(errorMessage.localizedDescription))
        }
    }

    private var LogoutButton: some View {
        Button(action: {
            promptLogoutAlert()
        }, label: {
            // TODO: loc
            Text("Sign Out...")
                .foregroundColor(BeamColor.Generic.text.swiftUI)
        }).disabled(!loggedIn)
            .frame(width: 83, height: 20, alignment: .center)
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

            Text("Your encryption key is used to decrypt your cards on Beam Web. Click to copy it and paste it on Beam Web.")
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .font(BeamFont.regular(size: 11).swiftUI)
                .foregroundColor(BeamColor.Corduroy.swiftUI)
                .frame(width: 354, height: 26, alignment: .leading)
        }
    }

    private func disconnectButton(_ identity: IdentityType) -> some View {
        guard let id = identity.id else { return AnyView(EmptyView()) }

        return AnyView(Button(action: {
            IdentityRequest().delete(id).then { _ in
                if identity.provider == IdentityRequest.Provider.google.rawValue {
                    Persistence.Authentication.googleAccessToken = nil
                    Persistence.Authentication.googleRefreshToken = nil
                }
                self.fetchIdentities()
                AppDelegate.main.data.calendarManager.disconnect(calendarService: .googleCalendar)
            }
        }, label: {
            if let provider = identity.provider {
                Text("Disconnect \(provider.prefix(1).capitalized + provider.dropFirst())...")
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(width: 126)
            } else {
                Text("Disconnect...")
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(width: 126)
            }
        }).disabled(!loggedIn))
    }

    private func fetchIdentities() {
        guard AuthenticationManager.shared.isAuthenticated else { return }

        email = Persistence.Authentication.email ?? ""
        password = Persistence.Authentication.password ?? ""

        IdentityRequest().fetchAll().then { identities in
            self.identities = identities
        }
    }

    private func promptLogoutAlert() {
        let alert = NSAlert()
        alert.messageText = "Are you sure you want to sign out from your Beam account?"
        alert.addButton(withTitle: "Sign Out")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard let window = AccountsPreferenceViewController.view.window else { return }
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            self.identities = []
            AccountManager.logout()
            #if !DEBUG
            password = ""
            #endif
            loggedIn = AccountManager().loggedIn
        }
    }

    // TODO: Implement when endpoint is ready
    private func promptDeleteAllGraphAlert() {
        let alert = NSAlert()
        alert.messageText = "Are you sure you want to delete all your graphs?"
        alert.informativeText = "All your cards will be deleted and cannot be recovered."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard let window = AccountsPreferenceViewController.view.window else { return }
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            // TODO: Implement
        }
    }

    // TODO: Implement when endpoint is ready
    private func promptDeleteAccountActionAlert() {
        let alert = NSAlert()
        alert.messageText = "Are you sure you want to delete your Beam account?"
        alert.informativeText = "Your account, all your graphs and all your cards will be deleted and cannot be recovered."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard let window = AccountsPreferenceViewController.view.window else { return }
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            // TODO: Implement when endpoint is ready
        }
    }
}

struct AccountCredentialsView: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var loggedIn: Bool
    @Binding var loading: Bool

    var body: some View {
        // TODO: loc
        TextField("johnnyappleseed@apple.com", text: $email)
            .textContentType(.username)
            .disabled(loggedIn || loading)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .frame(maxWidth: 200)
            .frame(width: 161, alignment: .leading)
        SecureField("Enter your password", text: $password)
            .textContentType(.password)
            .disabled(loggedIn || loading)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .frame(maxWidth: 200)
            .frame(width: 161, alignment: .leading)
    }
}

struct AccountsView_Previews: PreviewProvider {
    static var previews: some View {
        AccountsView(googleCalendarNeedsPermission: true)
        AccountsView(googleCalendarNeedsPermission: false)

    }
    // swiftlint:disable:next file_length
}
