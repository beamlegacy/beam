import Foundation
import os.log

// Inspired from https://www.avanderlee.com/swift/property-wrappers/

enum Persistence {
    enum Authentication {
        @KeychainStorable("authentication.accessToken") static var accessToken: String?
        @KeychainStorable("authentication.refreshToken") static var refreshToken: String?
        @KeychainStorable("authentication.userId") static var userId: String?
        @KeychainStorable("authentication.email") static var email: String?
        @KeychainStorable("authentication.password") static var password: String?
    }

    enum Development {
        @StandardStorable("development.endpoint") static var endpoint: String?
        @StandardStorable("development.lastLogin") static var lastLogin: Date?
    }

    enum Encryption {
        @KeychainStorable("encryption.privateKey") static var privateKey: String?
    }

    /// Clean all stored informations on logout
    static func cleanUp() {
        Persistence.Authentication.accessToken = nil
        Persistence.Authentication.refreshToken = nil
        Persistence.Authentication.userId = nil
    }
}
