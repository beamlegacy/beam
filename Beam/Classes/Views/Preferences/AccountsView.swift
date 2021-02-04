import SwiftUI
import Preferences

/**
Function wrapping SwiftUI into `PreferencePane`, which is mimicking view controller's default construction syntax.
*/
let AccountsPreferenceViewController: () -> PreferencePane = {
	/// Wrap your custom view into `Preferences.Pane`, while providing necessary toolbar info.
	let paneView = Preferences.Pane(
		identifier: .accounts,
		title: "Account",
		toolbarIcon: NSImage(named: "person.crop.circle")!
	) {
		AccountsView()
	}

	return Preferences.PaneHostingController(pane: paneView)
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

    private let accountManager = AccountManager()
    private let contentWidth: Double = 450.0

	var body: some View {
        Preferences.Container(contentWidth: contentWidth) {
            Preferences.Section(title: "Beam Account:") {
                // TODO: loc
                TextField("johnnyappleseed@apple.com", text: $email).textFieldStyle(RoundedBorderTextFieldStyle()).frame(maxWidth: 200)

                // TODO: loc
                SecureField("Enter your password", text: $password).textFieldStyle(RoundedBorderTextFieldStyle()).frame(maxWidth: 200)
                HStack {
                    SignInButton
                    SignUpButton
                }
                HStack {
                    ForgotPasswordButton
                    LogoutButton
                }
            }
		}
	}

    @State private var showingSignInAlert = false
    private var SignInButton: some View {
        Button(action: {
            accountManager.signIn(email, password) { result in
                loggedIn = AccountManager().loggedIn
                switch result {
                case .failure(let error):
                    errorMessage = error
                    showingSignInAlert = true
                    Logger.shared.logInfo("Could not signin: \(error.localizedDescription)", category: .network)
                case .success:
                    Logger.shared.logInfo("signIn succeeded", category: .network)
                }
            }
        }, label: {
            // TODO: loc
            Text("Sign In").frame(minWidth: 100)
        })
        .disabled(loggedIn)
        .alert(isPresented: $showingSignInAlert) {
            Alert(title: Text("Error"),
                  message: Text(errorMessage.localizedDescription))
        }
    }

    @State private var showingSignUpAlert = false
    private var SignUpButton: some View {
        Button(action: {
            accountManager.signUp(email, password) { result in
                switch result {
                case .failure(let error):
                    errorMessage = error
                    showingSignUpAlert = true
                    Logger.shared.logInfo("Could not sign up: \(error.localizedDescription)", category: .network)
                case .success:
                    Logger.shared.logInfo("signUp succeeded", category: .network)
                }
            }
        }, label: {
            // TODO: loc
            Text("Sign Up").frame(minWidth: 100)
        })
        .disabled(loggedIn)
        .alert(isPresented: $showingSignUpAlert) {
            Alert(title: Text("Error"),
                  message: Text(errorMessage.localizedDescription))
        }
    }

    @State private var showingForgotPasswordAlert = false
    private var ForgotPasswordButton: some View {
        Button(action: {
            accountManager.forgotPassword(email: email) { result in
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
        .disabled(loggedIn)
        .alert(isPresented: $showingForgotPasswordAlert) {
            Alert(title: Text("Error"),
                  message: Text(errorMessage.localizedDescription))
        }
    }

    private var LogoutButton: some View {
        Button(action: {
            AccountManager.logout()
            loggedIn = AccountManager().loggedIn
        }, label: {
            // TODO: loc
            Text("Logout").frame(minWidth: 100)
        }).disabled(!loggedIn)
    }
}

struct AccountsView_Previews: PreviewProvider {
	static var previews: some View {
		AccountsView()
	}
}
