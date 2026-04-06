import Foundation
import os.log
import BeamCore

// Inspired from https://www.avanderlee.com/swift/property-wrappers/

struct Persistence {
    enum Device {
        @StandardStorable("device.id") static var id: UUID?
    }

    enum Authentication {
        @KeychainStorable("authentication.email") static var email: String?

        @KeychainStorable("authentication.google.tokens", synchronizable: false) static var googleCalendarTokens: [String: String]?
        @StandardStorable("authentication.apple.calendar") static var hasAppleCalendarConnection: Bool?

        @StandardStorable("authentication.username") static var username: String?
        @StandardStorable("authentication.hasSeenOnboarding") static var hasSeenOnboarding: Bool?
        @StandardStorable("authentication.hasSeenWebTutorial") static var hasSeenWelcomeTour: Bool?
    }

    enum PointShoot {
        @StandardStorable("pns.border") static var border: Bool?
    }

    enum Encryption {
        static let localPrivateKeyName = Configuration.env.rawValue + ".encryption.localPrivateKey"
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

    /// Clean stored data
    static func cleanUp() {
        Persistence.Authentication.email = nil
        Persistence.Authentication.username = nil
        Persistence.Authentication.googleCalendarTokens = nil
        Persistence.Authentication.hasAppleCalendarConnection = nil
        Persistence.ImportedBrowserHistory.maxDateByBrowser = nil
    }

    static func emailOrRaiseError() -> String {
        return Persistence.Authentication.email ?? "local@beam.app"
    }
}
