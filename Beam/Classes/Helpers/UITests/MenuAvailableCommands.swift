import Foundation
import AppKit

public enum UITestMenuAvailableCommands: String, CaseIterable {
    // Clean up
    case destroyDB = "Destroy Databases"
    case signInWithTestAccount = "Sign in with Test Account"
    case logout = "Logout"
    case deleteLogs = "Delete Logs"
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

    // Notes
    case populateDBWithJournal = "Populate Journal"
    case insertTextInCurrentNote = "Insert Text in Current Note"
    case create100Notes = "Create 100 Random Notes"
    case create100NormalNotes = "Create 100 Normal Notes"
    case create100JournalNotes = "Create 100 Journal Notes"
    case create10Notes = "Create 10 Random Notes"
    case create10NormalNotes = "Create 10 Normal Notes"
    case create10JournalNotes = "Create 10 Journal Notes"

    // Passwords
    case populatePasswordsDB = "Populate Passwords Database"
    case clearPasswordsDB = "Clear Passwords Database"

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

    var group: UITestMenuGroup? {
        switch self {
        case .loadUITestPage1, .loadUITestPage2, .loadUITestPage3, .loadUITestPage4, .loadUITestPageMedia,
             .loadUITestPageAlerts, .loadUITestPagePassword, .loadUITestPagePlayground:
            return .loadHTMLPage
        case .populateDBWithJournal, .insertTextInCurrentNote,
                .create100Notes, .create100NormalNotes, .create100JournalNotes, .create10Notes, .create10NormalNotes, .create10JournalNotes:
            return .notes
        case .enableBrowsingSessionCollection, .disableBrowsingSessionCollection:
            return .browsingSession
        case .resizeSquare1000, .resizeWindowPortrait, .resizeWindowLandscape:
            return .resizeWindow
        case .populatePasswordsDB, .clearPasswordsDB:
            return .passwords
        case .startMockHttpServer, .stopMockHttpServer:
            return .mockHttpServer
        case .omniboxFillHistory:
            return .omniboxSetup
        case .enableCreateJournalOnce, .disableCreateJournalOnce:
            return .journal
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
    case omniboxSetup = "Omnibox Setup"
    case passwords = "Passwords"
    case mockHttpServer = "Mock HTTP Server"
    case resizeWindow = "Resize Window"
    case journal = "Journal"
}
