import SwiftUI
import Preferences
import BeamCore
import OAuthSwift

let AccountsPreferenceViewController: PreferencePane = PreferencesPaneBuilder.build(identifier: .accounts, title: "Account", imageName: "preferences-account") {
    AccountsView()
}

/**
The main view of “Accounts” preference pane.
*/
struct AccountsView: View {
    @State private var email: String = Persistence.Authentication.email ?? ""
    @State private var password: String = Persistence.Authentication.password ?? ""
    @State private var enableLogging: Bool = true
    @State private var loggedIn: Bool = AccountManager().loggedIn
    @State private var errorMessage: Error!
    @State private var loading: Bool = false
    @State private var identities: [IdentityType] = []

    private let accountManager = AccountManager()
    private let contentWidth: Double = PreferencesManager.contentWidth

	var body: some View {
        Preferences.Container(contentWidth: contentWidth) {
            Preferences.Section(title: "Account") {
                // TODO: loc
                if #available(OSX 11.0, *) {
                    TextField("johnnyappleseed@apple.com", text: $email)
                        .textContentType(.username)
                        .disabled(loggedIn || loading)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 200)
                } else {
                    TextField("johnnyappleseed@apple.com", text: $email)
                        .disabled(loggedIn || loading)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 200)
                }

                // TODO: loc
                if #available(OSX 11.0, *) {
                    SecureField("Enter your password", text: $password)
                        .textContentType(.password)
                        .disabled(loggedIn || loading)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 200)
                } else {
                    SecureField("Enter your password", text: $password)
                        .disabled(loggedIn || loading)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 200)
                }
            }

            Preferences.Section(title: "Actions") {
                HStack {
                    SignInButton
                    SignUpButton
                }
                HStack {
                    ForgotPasswordButton
                    LogoutButton
                }
            }

            Preferences.Section(title: "Login with") {
                GithubButton(buttonType: .signin, onClick: {
                    loading = true
                }, onConnect: {
                    loggedIn = AccountManager().loggedIn
                    fetchIdentities()
                    loading = false
                }, onFailure: {
                    loading = false
                }).disabled(loggedIn || loading)

                GoogleButton(buttonType: .signin, onClick: {
                    loading = true
                }, onConnect: {
                    loggedIn = AccountManager().loggedIn
                    fetchIdentities()
                    loading = false
                }, onFailure: {
                    loading = false
                }).disabled(loggedIn || loading)
            }

            Preferences.Section(title: "Connected Providers") {
                ForEach(identities, id: \.id) { identity in
                    disconnectButton(identity)
                }
            }

            Preferences.Section(title: "Connect Providers") {
                GithubButton(buttonType: .connect, onClick: {
                    loading = true
                }, onConnect: {
                    fetchIdentities()
                    loading = false
                }, onFailure: {
                    loading = false
                }).disabled(!loggedIn || loading || identities.compactMap { $0.provider }.contains("github"))

                GoogleButton(buttonType: .connect, onClick: {
                    loading = true
                }, onConnect: {
                    fetchIdentities()
                    loading = false
                }, onFailure: {
                    loading = false
                }).disabled(!loggedIn || loading || identities.compactMap { $0.provider }.contains("google"))
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

        ProgressIndicator(isAnimated: loading, controlSize: .small).padding()
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
                    Logger.shared.logInfo("Could not signin: \(error.localizedDescription)", category: .network)
                case .success:
                    Logger.shared.logInfo("signIn succeeded", category: .network)
                    self.fetchIdentities()
                }
            }
        }, label: {
            // TODO: loc
            Text("Sign In").frame(minWidth: 100)
        })
        .disabled(loggedIn || loading || email.isEmpty || password.isEmpty)
        .alert(isPresented: $showingSignInAlert) {
            Alert(title: Text("Error"),
                  message: Text(errorMessage.localizedDescription))
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
            Text("Sign Up").frame(minWidth: 100)
        })
        .disabled(loggedIn || loading || email.isEmpty || password.isEmpty)
        .alert(isPresented: $showingSignUpAlert) {
            Alert(title: Text("Error"),
                  message: Text(errorMessage.localizedDescription))
        }
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
            self.identities = []
            AccountManager.logout()
            loggedIn = AccountManager().loggedIn
        }, label: {
            // TODO: loc
            Text("Logout").frame(minWidth: 100)
        }).disabled(!loggedIn)
    }

    private func disconnectButton(_ identity: IdentityType) -> some View {
        guard let id = identity.id else { return AnyView(EmptyView()) }

        return AnyView(Button(action: {
            IdentityRequest().delete(id).then { _ in
                self.fetchIdentities()
            }
        }, label: {
            Text("Disconnect \(identity.provider ?? "-") (\(identity.email ?? "-"))")
                .frame(minWidth: 100)
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
}

struct AccountsView_Previews: PreviewProvider {
	static var previews: some View {
		AccountsView()
	}
}
