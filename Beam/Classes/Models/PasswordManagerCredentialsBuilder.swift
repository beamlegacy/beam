//
//  PasswordManagerCredentialsBuilder.swift
//  Beam
//
//  Created by Beam on 15/09/2021.
//

import Foundation

final class PasswordManagerCredentialsBuilder {
    private var currentHost: String?
    private var selectedCredentials: PasswordManagerEntry?
    private var storedUsername: String?

    func enterPage(url: URL?) {
        let newHost = url?.minimizedHost
        if newHost != currentHost {
            reset()
            currentHost = newHost
        }
    }

    func suggestedEntry() -> PasswordManagerEntry? {
        return selectedCredentials
    }

    var hasManualInput: Bool {
        storedUsername != nil
    }

    func selectCredentials(_ entry: PasswordManagerEntry) {
        selectedCredentials = entry
    }

    func updatedUsername(_ username: String?) -> String? {
        if let username = username {
            storedUsername = username
        }
        return storedUsername
    }

    private func reset() {
        selectedCredentials = nil
        storedUsername = nil
    }
}
