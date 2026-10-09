import Foundation
import os.log
import BeamCore

// Inspired from https://www.avanderlee.com/swift/property-wrappers/

struct Persistence {
    enum Device {
        @StandardStorable("device.id") static var id: UUID?
    }

    enum Authentication {
        @KeychainStorable("authentication.google.tokens", synchronizable: false) static var googleCalendarTokens: [String: String]?
        @StandardStorable("authentication.apple.calendar") static var hasAppleCalendarConnection: Bool?

        @StandardStorable("authentication.hasSeenOnboarding") static var hasSeenOnboarding: Bool?
        @StandardStorable("authentication.hasSeenWebTutorial") static var hasSeenWelcomeTour: Bool?
    }

    enum PointShoot {
        @StandardStorable("pns.border") static var border: Bool?
    }

    enum Encryption {
        static let localPrivateKeyName = Configuration.env.rawValue + ".encryption.localPrivateKey"
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

    enum PinnedNotes {
        @StandardStorable("pinnedNotesId") static var pinnedNotesId: [String]?
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

    enum NoteScores {
        @StandardStorable("NoteScores.daily") static var daily: Data?
        @StandardStorable("NoteScores.lastWordCountChange") static var lastWordCountChange: Data?
    }

    enum Account {
        @StandardStorable("currentAccount.id") static var currentAccountId: UUID?
        @StandardStorable("currentDatabase.id") static var currentDatabaseId: UUID?
    }

    enum SpellChecking {
        @StandardStorable("spellChecking.enable") static var enable: Bool?
        @StandardStorable("spellChecking.ignored") static var ignoredWords: [String]?
    }

    /// Clean calendar connections and browser import state
    static func cleanUp() {
        Persistence.Authentication.googleCalendarTokens = nil
        Persistence.Authentication.hasAppleCalendarConnection = nil
        Persistence.ImportedBrowserHistory.maxDateByBrowser = nil
    }

    /// Account and sync data stored by versions of Beam that had an online service.
    enum LegacyAccountData {
        @KeychainStorable("authentication.accessToken") private static var accessToken: String?
        @KeychainStorable("authentication.refreshToken") private static var refreshToken: String?
        @KeychainStorable("authentication.userId") private static var userId: String?
        @KeychainStorable("authentication.email") private static var email: String?
        @KeychainStorable("authentication.password") private static var password: String?
        @KeychainStorable("encryption.privateKeys") private static var syncPrivateKeys: [String: String]?
        @KeychainStorable("encryption.privateKey") private static var sharedPrivateKey: String?
        @KeychainStorable("encryption.privateKeyCreationDate") private static var privateKeyCreationDate: Date?
        @KeychainStorable("encryption.privateKeyUpdateDate") private static var privateKeyUpdateDate: Date?
        @StandardStorable("authentication.username") private static var username: String?
        @StandardStorable("development.endpoint") private static var endpoint: String?
        @StandardStorable("development.lastLogin") private static var lastLogin: Date?
        @StandardStorable("browsingTree.userId") private static var browsingTreeUserId: String?
        @StandardStorable("sync.beam_objects.last_received_at") private static var lastReceivedAt: Date?
        @StandardStorable("sync.beam_objects.last_updated_at") private static var lastUpdatedAt: Date?
        @StandardStorable("legacyAccountData.removed.v2") private static var removed: Bool?

        /// Removes the stored credentials (email, password, tokens), sync encryption keys and sync state, once.
        /// The local private key encrypting saved passwords (`encryption.localPrivateKey`) is not affected.
        static func removeIfNeeded() {
            guard removed != true else { return }
            accessToken = nil
            refreshToken = nil
            userId = nil
            email = nil
            password = nil
            syncPrivateKeys = nil
            sharedPrivateKey = nil
            privateKeyCreationDate = nil
            privateKeyUpdateDate = nil
            username = nil
            endpoint = nil
            lastLogin = nil
            browsingTreeUserId = nil
            lastReceivedAt = nil
            lastUpdatedAt = nil
            removed = true
        }
    }
}
