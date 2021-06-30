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

    enum PointShoot {
        @StandardStorable("pns.border") static var border: Bool?
    }

    enum Encryption {
        @KeychainStorable("encryption.privateKey") static var privateKey: String?
    }

    // swiftlint:disable nesting
    enum Sync {
        enum Databases {
            @StandardStorable("sync.databases.updated_at") static var updated_at: Date?
        }
        enum Documents {
            @StandardStorable("sync.documents.updated_at") static var updated_at: Date?
            @StandardStorable("sync.documents.sent_all_at") static var sent_all_at: Date?
        }
        enum BeamObjects {
            @StandardStorable("sync.beam_objects.updated_at") static var updated_at: Date?
        }

        /// Clean all stored informations on logout
        static func cleanUp() {
            Persistence.Sync.Databases.updated_at = nil
            Persistence.Sync.Documents.updated_at = nil
            Persistence.Sync.BeamObjects.updated_at = nil
            Persistence.Sync.Documents.sent_all_at = nil
        }
    }

    /// Clean all stored informations on logout
    static func cleanUp() {
        Persistence.Authentication.accessToken = nil
        Persistence.Authentication.refreshToken = nil
        Persistence.Authentication.userId = nil
        Sync.cleanUp()
    }
}
