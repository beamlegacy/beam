import Foundation
import os.log
import BeamCore

// Inspired from https://www.avanderlee.com/swift/property-wrappers/

enum Persistence {
    enum Authentication {
        @KeychainStorable("authentication.accessToken") static var accessToken: String?
        @KeychainStorable("authentication.refreshToken") static var refreshToken: String?
        @KeychainStorable("authentication.userId") static var userId: String?
        @KeychainStorable("authentication.email") static var email: String?
        @KeychainStorable("authentication.password") static var password: String?

        @KeychainStorable("authentication.google.tokens", synchronizable: false) static var googleCalendarTokens: String?

        @StandardStorable("authentication.username") static var username: String?
        @StandardStorable("authentication.hasSeenOnboarding") static var hasSeenOnboarding: Bool?
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

    enum ContinueTo {
        @StandardStorable("summary") static var summary: String?
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
        Persistence.Authentication.email = nil
        Persistence.Authentication.username = nil
        Persistence.Authentication.password = nil
        Persistence.Authentication.googleCalendarTokens = nil
        Sync.cleanUp()
    }
}
