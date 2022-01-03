import Foundation
import AppKit

public enum UITestMenuAvailableCommands: String, CaseIterable {
    // Clean up
    case destroyDB = "Destroy Databases"
    case signInWithTestAccount = "Sign in with Test Account"
    case logout = "Logout"
    case deleteLogs = "Delete Logs"
    case showOnboarding = "Reset Onboarding"
    case clearPasswordsDB = "Clear Passwords Database"

    case separatorA
    case resizeWindowLandscape = "Resize Window to Landscape"
    case resizeWindowPortrait = "Resize Window to Portrait"
    case resizeSquare1000 = "Resize Window Square"
    case enableBrowsingSessionCollection = "Enable BrowsingSession Collect"
    case disableBrowsingSessionCollection = "Disable BrowsingSession Collect"

    case separatorB
    // Load HTML Page
    case loadUITestPage1 = "Load UITests Page 1"
    case loadUITestPage2 = "Load UITests Page 2"
    case loadUITestPage3 = "Load UITests Page 3"
    case loadUITestPage4 = "Load UITests Page 4"
    case loadUITestPagePassword = "Load PasswordManager test page"
    case loadUITestPagePlayground = "Load HTML playground"
    case loadUITestPageAlerts = "Load JS/Native alert panels"
    case loadUITestPageMedia = "Load Media test page"

    case separatorC
    // setup
    case populateDBWithJournal = "Populate Journal"
    case insertTextInCurrentNote = "Insert Text in Current Note"
    case create100Notes = "Create 100 Random Notes"
    case create100NormalNotes = "Create 100 Normal Notes"
    case create100JournalNotes = "Create 100 Journal Notes"
    case create10Notes = "Create 10 Random Notes"
    case create10NormalNotes = "Create 10 Normal Notes"
    case create10JournalNotes = "Create 10 Journal Notes"
    case setAutoUpdateToMock = "Set Autoupdate to Mock"
    case cleanDownloads = "Clean SF-Symbols-3.dmg from Downloads"
    case populatePasswordsDB = "Populate Passwords Database"
    case showWebViewCount = "Show Number of WebView in Memory"

    // Omnibox setup
    case omniboxFillHistory = "Fill History with Results"

    var group: UITestMenuGroup? {
        switch self {
        case .loadUITestPage1, .loadUITestPage2, .loadUITestPage3, .loadUITestPage4, .loadUITestPageMedia,
             .loadUITestPageAlerts, .loadUITestPagePassword, .loadUITestPagePlayground:
            return .loadHTMLPage
        case .omniboxFillHistory:
            return .omniboxSetup
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
    case loadHTMLPage = "Load UITest HTML Page"
    case omniboxSetup = "Omnibox Setup"
}
