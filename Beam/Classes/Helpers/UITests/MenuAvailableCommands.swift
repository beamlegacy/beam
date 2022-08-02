import Foundation
import AppKit

public enum UITestMenuAvailableCommands: String, CaseIterable {
    // Clean up
    case destroyDB = "Destroy Databases"
    case deleteLogs = "Delete Logs"
    case deletePrivateKeys = "Delete Private Keys"
    case deleteAllRemoteObjects = "Delete All Remote Objects"

    case showOnboarding = "Reset Onboarding"
    case resetCollectAlert = "Reset Collect Alert"

    // Account
    case signInWithTestAccount = "Sign in with Test Account"
    case signUpWithRandomTestAccount = "Sign up with Random Test Account"
    case logout = "Logout"

    // Preferences
    case startBeamOnDefault = "Start beam on: default"
    case startBeamOnTabs = "Start beam on: opened tabs"
    case separatorInPreferencesA // before: public prefs, after: advanced only prefs
    case enableBrowsingSessionCollection = "BrowsingSession Collect: Enable"
    case disableBrowsingSessionCollection = "BrowsingSession Collect: Disable"
    case enableCreateJournalOnce = "Create Journal once per window: Enable"
    case disableCreateJournalOnce = "Create Journal once per window: Disable"
    case resetUserPreferences = "Reset User Preferences"

    case separatorA

    // Resize Window
    case resizeWindowLandscape = "Resize Window to Landscape"
    case resizeWindowPortrait = "Resize Window to Portrait"
    case resizeSquare1000 = "Resize Window Square"

    // Web Tabs
    case loadUITestPage1 = "Load UITests Page 1"
    case loadUITestPage2 = "Load UITests Page 2"
    case loadUITestPage3 = "Load UITests Page 3"
    case loadUITestPage4 = "Load UITests Page 4"
    case loadUITestPagePassword = "Load PasswordManager test page"
    case loadUITestPagePlayground = "Load HTML playground"
    case loadUITestPageAlerts = "Load JS/Native alert panels"
    case loadUITestPageMedia = "Load Media test page"
    case loadUITestSVG = "Load UITests SVG"
    case separatorWebTabsA
    case createTabGroup = "Create Tab Group"
    case createTabGroupNamed = "Create Tab Group with Name"

    // Notes
    case populateDBWithJournal = "Populate Journal"
    case insertTextInCurrentNote = "Insert Text in Current Note"
    case create100Notes = "Create 100 Random Notes"
    case create100NormalNotes = "Create 100 Normal Notes"
    case create100JournalNotes = "Create 100 Journal Notes"
    case create10Notes = "Create 10 Random Notes"
    case create10NormalNotes = "Create 10 Normal Notes"
    case create10JournalNotes = "Create 10 Journal Notes"
    case createFakeDailySummary = "Create Fake Daily Summary"
    case createNote = "Create Note"
    case createAndOpenNote = "Create and Open Note"
    case createPublishedNote = "Create Published Note"
    case createAndOpenPublishedNote = "Create and Open Published Note"

    // Links
    case create1000Links = "Create 1,000 Links"
    case create10000Links = "Create 10,000 Links"
    case create50000Links = "Create 50,000 Links"

    // Passwords & Credit Cards
    case populatePasswordsDB = "Passwords Database: Populate"
    case clearPasswordsDB = "Passwords Database: Clear"
    case populateCreditCardsDB = "Credit Cards Database: Populate"
    case clearCreditCardsDB = "Credit Cards Database: Clear"
    case separatorInPasswordA
    case disablePasswordProtect = "Disable Protection for Password & Credit Cards"

    // Mock HTTP Server
    case startMockHttpServer = "Start Mock HTTP Server"
    case stopMockHttpServer = "Stop Mock HTTP Server"

    // Omnibox setup
    case omniboxFillHistory = "Fill History with Results"
    case omniboxEnableSearchInHistoryContent = "Search in history content: Enable"
    case omniboxDisableSearchInHistoryContent = "Search in history content: Disable"

    // Remote server
    case resetAPIEndpoints = "Set API Endpoints to production server"
    case setAPIEndpointsToStaging = "Set API Endpoints to staging server"
    case deleteRemoteAccount = "Delete remote account"

    // Others
    case separatorB
    case setAutoUpdateToMock = "Set Autoupdate to Mock"
    case cleanDownloads = "Clean SF-Symbols-3.dmg from Downloads"
    case showWebViewCount = "Show Number of WebView in Memory"

    var group: UITestMenuGroup? {
        switch self {
        case .loadUITestPage1, .loadUITestPage2, .loadUITestPage3, .loadUITestPage4, .loadUITestPageMedia, .loadUITestSVG,
             .loadUITestPageAlerts, .loadUITestPagePassword, .loadUITestPagePlayground,
             .separatorWebTabsA, .createTabGroup, .createTabGroupNamed:
            return .webTabs
        case .populateDBWithJournal, .insertTextInCurrentNote,
                .create100Notes, .create100NormalNotes, .create100JournalNotes, .create10Notes, .create10NormalNotes, .create10JournalNotes,
                .createFakeDailySummary, .createNote, .createAndOpenNote, .createPublishedNote, .createAndOpenPublishedNote:
            return .notes
        case .create1000Links, .create10000Links, .create50000Links:
            return .links
        case .resizeSquare1000, .resizeWindowPortrait, .resizeWindowLandscape:
            return .resizeWindow
        case .populatePasswordsDB, .clearPasswordsDB, .populateCreditCardsDB, .clearCreditCardsDB, .disablePasswordProtect, .separatorInPasswordA:
            return .passwordsAndCards
        case .startMockHttpServer, .stopMockHttpServer:
            return .mockHttpServer
        case .omniboxFillHistory, .omniboxEnableSearchInHistoryContent, .omniboxDisableSearchInHistoryContent:
            return .omniboxSetup
        case .resetAPIEndpoints, .setAPIEndpointsToStaging, .deleteRemoteAccount:
            return .remoteServer
        case .separatorInPreferencesA, .startBeamOnDefault, .startBeamOnTabs, .enableCreateJournalOnce, .disableCreateJournalOnce,
                .enableBrowsingSessionCollection, .disableBrowsingSessionCollection, .resetUserPreferences:
            return .preferences
        case .signInWithTestAccount, .signUpWithRandomTestAccount, .logout:
            return .account
        default:
            return nil
        }
    }

    var shortcut: (key: String, modifiers: NSEvent.ModifierFlags)? {
        switch self {
        default:
            return nil
        }
    }
}

public enum UITestMenuGroup: String, CaseIterable {
    case account = "Account"
    case webTabs = "Web Tabs"
    case notes = "Notes"
    case links = "Links"
    case omniboxSetup = "Omnibox Setup"
    case passwordsAndCards = "Passwords & Credit Cards"
    case mockHttpServer = "Mock HTTP Server"
    case resizeWindow = "Resize Window"
    case remoteServer = "Remote server"
    case preferences = "Preferences"
}
