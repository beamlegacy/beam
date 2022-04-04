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

        @KeychainStorable("authentication.google.tokens", synchronizable: false) static var googleCalendarTokens: [String: String]?

        @StandardStorable("authentication.username") static var username: String?
        @StandardStorable("authentication.hasSeenOnboarding") static var hasSeenOnboarding: Bool?
        @StandardStorable("authentication.hasSeenWebTutorial") static var hasSeenWelcomeTour: Bool?
    }

    enum Development {
        @StandardStorable("development.endpoint") static var endpoint: String?
        @StandardStorable("development.lastLogin") static var lastLogin: Date?
    }

    enum PointShoot {
        @StandardStorable("pns.border") static var border: Bool?
    }

    enum Encryption {
        @KeychainStorable("encryption.localPrivateKey", synchronizable: false) static var localPrivateKey: String?
        @KeychainStorable("encryption.privateKeys") static var privateKeys: [String: String]?

        // This is deprecated but we keep it as for now
        @KeychainStorable("encryption.privateKey") static var privateKey: String?
        // This is not saved in the keychain
        @KeychainStorable("encryption.privateKeyCreationDate") static var creationDate: Date?
        @KeychainStorable("encryption.privateKeyUpdateDate") static var updateDate: Date?

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
    enum TabPinSuggestion {
        @StandardStorable("tabPinSuggestion.hasPinned") static var hasPinned: Bool?
    }
    enum ImportedBrowserHistory {
        @StandardStorable("importedBrowserHistory.maxDateByBrowser") static var maxDateByBrowser: Data?

        static func save(maxDate: Date, browserType: BrowserType) {
            let decoder = JSONDecoder()
            var importDates = [BrowserType: Date]()
            if let maxDateByBrowser = maxDateByBrowser {
                importDates = (try? decoder.decode([BrowserType: Date].self, from: maxDateByBrowser)) ?? [BrowserType: Date]()
            }
            importDates[browserType] = max(maxDate, importDates[browserType] ?? Date.distantPast)
            maxDateByBrowser = try? JSONEncoder().encode(importDates)
        }
        static func getMaxDate(for browserType: BrowserType) -> Date? {
            let decoder = JSONDecoder()
            guard let maxDateByBrowser = maxDateByBrowser,
                  let decodedMaxDateByBrowser = (try? decoder.decode([BrowserType: Date].self, from: maxDateByBrowser))
            else { return nil }
            return decodedMaxDateByBrowser[browserType]
        }
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
        Persistence.ImportedBrowserHistory.maxDateByBrowser = nil
        Sync.cleanUp()
    }

    static func emailOrRaiseError() -> String {
        guard let email = Persistence.Authentication.email else {
            fatalError("Email is nil and it should not")
        }

        guard !email.isEmpty else {
            fatalError("Email is empty and it should not")
        }

        return email
    }
}
