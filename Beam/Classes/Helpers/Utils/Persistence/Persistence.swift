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

        @KeychainStorable("authentication.google.accessToken") static var googleAccessToken: String?
        @KeychainStorable("authentication.google.refreshToken") static var googleRefreshToken: String?

        //For now, we just store the username in-memory.
        //This have to change when we can have a better sync of it, to ensure it's always in sync with the backend
        static var username: String?
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

    enum BrowsingTree {
        @StandardStorable("browsingTree.userId") static var userId: String?
    }

    enum TopDomains {
        @StandardStorable("last_fetched_at") static var lastFetchedAt: Date?
        @StandardStorable("top_domains.version") static var version: String?
    }

    enum Database {
        @StandardStorable("currentDatabaseId") static var currentDatabaseId: UUID?
    }

    // swiftlint:disable nesting
    enum Sync {
        enum BeamObjects {
            @StandardStorable("sync.beam_objects.last_received_at") static var last_received_at: Date?
            @StandardStorable("sync.beam_objects.last_updated_at") static var last_updated_at: Date?
        }

        /// Clean all stored informations on logout
        static func cleanUp() {
            Persistence.Sync.BeamObjects.last_received_at = nil
            Persistence.Sync.BeamObjects.last_updated_at = nil
        }
    }
    /// Clean all stored informations on logout
    static func cleanUp() {
        Persistence.Authentication.accessToken = nil
        Persistence.Authentication.refreshToken = nil
        Persistence.Authentication.userId = nil
        Persistence.Authentication.googleAccessToken = nil
        Persistence.Authentication.googleRefreshToken = nil
        Sync.cleanUp()
    }
}
