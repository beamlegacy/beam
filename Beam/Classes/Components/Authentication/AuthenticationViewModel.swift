//
//  AuthenticationViewModel.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 27/07/2021.
//

import Foundation

class AuthenticationViewModel: ObservableObject {

    @Published var username: String = ""
    @Published var password: String = ""
    @Published var savePassword: Bool = false

    let host: String
    let port: Int
    let isSecured: Bool

    private var onValidate: ((String, String, Bool) -> Void)?
    private var onCancel: (() -> Void)?
    private var challenge: URLAuthenticationChallenge

    init(challenge: URLAuthenticationChallenge,
         onValidate: @escaping (String, String, Bool) -> Void, onCancel: @escaping () -> Void) {
        self.host = challenge.protectionSpace.host
        self.port = challenge.protectionSpace.port
        self.challenge = challenge
        self.isSecured = challenge.protectionSpace.receivesCredentialSecurely
        self.onValidate = onValidate
        self.onCancel = onCancel
    }

    // This init is for design purpose
    init(host: String, port: Int, isSecured: Bool,
         onValidate: @escaping (String, String, Bool) -> Void, onCancel: @escaping () -> Void) {
        self.host = host
        self.port = port
        self.isSecured = isSecured
        self.onValidate = onValidate
        self.onCancel = onCancel

        self.challenge = URLAuthenticationChallenge()
    }

    func validate() {
        onValidate?(username, password, savePassword)
        onValidate = nil
    }

    func cancel() {
        onCancel?()
        onCancel = nil
    }

    var serverDescription: String {
        return "\(host):\(port)"
    }

    var securityMessage: String {
        if isSecured {
            return "Your login information will be sent securely."
        } else {
            return "Your password will be sent unencrypted."
        }
    }
}

extension AuthenticationViewModel: Hashable {
    static func == (lhs: AuthenticationViewModel, rhs: AuthenticationViewModel) -> Bool {
        lhs.challenge == rhs.challenge
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(challenge)
    }
}
