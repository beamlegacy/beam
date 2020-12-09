import SwiftUI

struct AccountDetail: View {
    @State private var email: String = Persistence.Authentication.email ?? ""
    @State private var password: String = Persistence.Authentication.password ?? ""
    @State private var enableLogging: Bool = true
    @State private var loggedIn: Bool = AccountManager().loggedIn

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

                        Button(action: {
                            accountManager.signIn(email: email, password: password) { result in
                                switch result {
                                case .failure(let error):
                                    BMLogger.shared.logInfo("Could not signin: \(error.localizedDescription)", category: .network)
                                case .success:
                                    BMLogger.shared.logInfo("signIn succeeded", category: .network)
                                }
                            }
                        }, label: {
                            // TODO: loc
                            Text("Sign In").frame(minWidth: 100)
                        })
                        .disabled(loggedIn)
                        Button(action: {
                            accountManager.signUp(email, password) { result in
                                switch result {
                                case .failure(let error):
                                    BMLogger.shared.logInfo("Could not sign up: \(error.localizedDescription)", category: .network)
                                case .success:
                                    BMLogger.shared.logInfo("signUp succeeded", category: .network)
                                }
                            }
                        }, label: {
                            // TODO: loc
                            Text("Sign Up").frame(minWidth: 100)
                        }).disabled(loggedIn)
                        Button(action: {
                            accountManager.forgotPassword(email: email) { result in
                                switch result {
                                case .failure(let error):
                                    BMLogger.shared.logInfo("Could not forgot password: \(error.localizedDescription)", category: .network)
                                case .success:
                                    BMLogger.shared.logInfo("forgot Password succeeded", category: .network)
                                }
                            }
                        }, label: {
                            // TODO: loc
                            Text("Forgot Password").frame(minWidth: 100)
                        }).disabled(loggedIn)
                        Button(action: {
                            accountManager.logout()
                        }, label: {
                            // TODO: loc
                            Text("Logout").frame(minWidth: 100)
                        }).disabled(!loggedIn)
                        Spacer()

                    }.padding()
                }
            }.padding()
            Spacer()
        }
    }
}

struct AccountDetail_Previews: PreviewProvider {
    static var previews: some View {
        AccountDetail()
    }
}
