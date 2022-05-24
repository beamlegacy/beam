import Foundation
import AppKit

public enum UITestMenuAvailableCommands: String, CaseIterable {
    // Clean up
    case destroyDB = "Destroy Databases"
    case signInWithTestAccount = "Sign in with Test Account"
    case signUpWithRandomTestAccount = "Sign up with Random Test Account"
    case logout = "Logout"
    case deleteLogs = "Delete Logs"
    case deletePrivateKeys = "Delete Private Keys"
    case deleteAllRemoteObjects = "Delete All Remote Objects"

    case showOnboarding = "Reset Onboarding"
    case resetCollectAlert = "Reset Collect Alert"

    case separatorA

    // Resize Window
    case resizeWindowLandscape = "Resize Window to Landscape"
    case resizeWindowPortrait = "Resize Window to Portrait"
    case resizeSquare1000 = "Resize Window Square"

    // Browsing Session
    case enableBrowsingSessionCollection = "Enable BrowsingSession Collect"
    case disableBrowsingSessionCollection = "Disable BrowsingSession Collect"

    // Load HTML Page
    case loadUITestPage1 = "Load UITests Page 1"
    case loadUITestPage2 = "Load UITests Page 2"
    case loadUITestPage3 = "Load UITests Page 3"
    case loadUITestPage4 = "Load UITests Page 4"
    case loadUITestPagePassword = "Load PasswordManager test page"
    case loadUITestPagePlayground = "Load HTML playground"
    case loadUITestPageAlerts = "Load JS/Native alert panels"
    case loadUITestPageMedia = "Load Media test page"
    case loadUITestSVG = "Load UITests SVG"

    // Notes
    case populateDBWithJournal = "Populate Journal"
    case insertTextInCurrentNote = "Insert Text in Current Note"
    case create100Notes = "Create 100 Random Notes"
    case create100NormalNotes = "Create 100 Normal Notes"
    case create100JournalNotes = "Create 100 Journal Notes"
    case create10Notes = "Create 10 Random Notes"
    case create10NormalNotes = "Create 10 Normal Notes"
    case create10JournalNotes = "Create 10 Journal Notes"

    // Links
    case create1000Links = "Create 1,000 Links"
    case create10000Links = "Create 10,000 Links"
    case create50000Links = "Create 50,000 Links"

    // Passwords
    case populatePasswordsDB = "Populate Passwords Database"
    case clearPasswordsDB = "Clear Passwords Database"

    // Credit Cards
    case populateCreditCardsDB = "Populate Credit Cards Database"
    case clearCreditCardsDB = "Clear Credit Cards Database"

    // Mock HTTP Server
    case startMockHttpServer = "Start Mock HTTP Server"
    case stopMockHttpServer = "Stop Mock HTTP Server"

    // Omnibox setup
    case omniboxFillHistory = "Fill History with Results"
    case omniboxEnableSearchInHistoryContent = "Enable search in history content"
    case omniboxDisableSearchInHistoryContent = "Disable search in history content"

    // Others
    case separatorB
    case setAutoUpdateToMock = "Set Autoupdate to Mock"
    case cleanDownloads = "Clean SF-Symbols-3.dmg from Downloads"
    case showWebViewCount = "Show Number of WebView in Memory"

    // Journal
    case enableCreateJournalOnce = "Enable Create Journal once per window"
    case disableCreateJournalOnce = "Disable Create Journal once per window"

    // Remote server
    case resetAPIEndpoints = "Set API Endpoints to production server"
    case setAPIEndpointsToStaging = "Set API Endpoints to staging server"
    case deleteRemoteAccount = "Delete remote account"

    var group: UITestMenuGroup? {
        switch self {
        case .loadUITestPage1, .loadUITestPage2, .loadUITestPage3, .loadUITestPage4, .loadUITestPageMedia, .loadUITestSVG,
             .loadUITestPageAlerts, .loadUITestPagePassword, .loadUITestPagePlayground:
            return .loadHTMLPage
        case .populateDBWithJournal, .insertTextInCurrentNote,
                .create100Notes, .create100NormalNotes, .create100JournalNotes, .create10Notes, .create10NormalNotes, .create10JournalNotes:
            return .notes
        case .create1000Links, .create10000Links, .create50000Links:
            return .links
        case .enableBrowsingSessionCollection, .disableBrowsingSessionCollection:
            return .browsingSession
        case .resizeSquare1000, .resizeWindowPortrait, .resizeWindowLandscape:
            return .resizeWindow
        case .populatePasswordsDB, .clearPasswordsDB:
            return .passwords
        case .populateCreditCardsDB, .clearCreditCardsDB:
            return .creditCards
        case .startMockHttpServer, .stopMockHttpServer:
            return .mockHttpServer
        case .omniboxFillHistory:
            return .omniboxSetup
        case .enableCreateJournalOnce, .disableCreateJournalOnce:
            return .journal
        case .resetAPIEndpoints, .setAPIEndpointsToStaging, .deleteRemoteAccount:
            return .remoteServer
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
    case browsingSession = "Browsing Session"
    case loadHTMLPage = "Load UITest HTML Page"
    case notes = "Notes"
    case links = "Links"
    case omniboxSetup = "Omnibox Setup"
    case passwords = "Passwords"
    case creditCards = "Credit Cards"
    case mockHttpServer = "Mock HTTP Server"
    case resizeWindow = "Resize Window"
    case journal = "Journal"
    case remoteServer = "Remote server"
}
