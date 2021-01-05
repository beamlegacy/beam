import SwiftUI

struct AccountDetail: View {
    @State private var email: String = Persistence.Authentication.email ?? ""
    @State private var password: String = Persistence.Authentication.password ?? ""
    @State private var enableLogging: Bool = true
    @State private var loggedIn: Bool = AccountManager().loggedIn
    @State private var errorMessage: Error!

    let accountManager = AccountManager()

    var body: some View {
        VStack {
            Form {
                Section {
                    // TODO: loc
                    TextField("johnnyappleseed@apple.com", text: $email).textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                }

                Section {
                    // TODO: loc
                    SecureField("Enter your password", text: $password).textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                }

                Divider()

                Section {
                    HStack(alignment: .center) {
                        Spacer()

                        SignInButton

                        SignUpButton

                        ForgotPasswordButton

                        LogoutButton

                        ResetAPIEndpointsButton

                        Spacer()

                    }.padding()
                }
            }.padding()
            Spacer()
        }
    }

    @State private var showingSignInAlert = false
    private var SignInButton: some View {
        Button(action: {
            accountManager.signIn(email: email, password: password) { result in
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

    private var ResetAPIEndpointsButton: some View {
        Button(action: {
            Configuration.reset()
        }, label: {
            // TODO: loc
            Text("Reset API Endpoints").frame(minWidth: 100)
        })
    }
}

struct AccountDetail_Previews: PreviewProvider {
    static var previews: some View {
        AccountDetail()
    }
}
