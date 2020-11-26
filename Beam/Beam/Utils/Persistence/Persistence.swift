import Foundation
import os.log

// Inspired from https://www.avanderlee.com/swift/property-wrappers/

enum Persistence {
    enum Analytics {
        @StandardStorable("Analytics.approved") static var approved: Bool?
    }

    enum Authentication {
        @StandardStorable("Authentication.accessToken") static var accessToken: String?
        @StandardStorable("Authentication.refreshToken") static var refreshToken: String?
        @StandardStorable("Authentication.userId") static var userId: String?
        @StandardStorable("Authentication.email") static var email: String?
        @StandardStorable("Authentication.password") static var password: String?
    }

    enum Development {
        @StandardStorable("Development.endpoint") static var endpoint: String?
        @StandardStorable("Development.lastLogin") static var lastLogin: Date?
    }

    /// Clean all stored informations on logout
    static func cleanUp() {
        Persistence.Authentication.accessToken = nil
        Persistence.Authentication.refreshToken = nil
        Persistence.Authentication.userId = nil
    }
}
