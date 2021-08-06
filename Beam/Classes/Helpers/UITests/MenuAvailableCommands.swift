import Foundation

public enum MenuAvailableCommands: String, CaseIterable {
    case populateDBWithJournal = "Populate Journal"
    case destroyDB = "Destroy Databases"
    case logout = "Logout"
    case deleteLogs = "Delete Logs"
    case separatorA
    case resizeWindowLandscape = "Resize Window to Landscape"
    case resizeWindowPortrait = "Resize Window to Portrait"
    case separatorB
    case loadUITestPage1 = "Load UITests Page 1"
    case loadUITestPage2 = "Load UITests Page 2"
    case loadUITestPage3 = "Load UITests Page 3"
    case loadUITestPagePassword = "Load PasswordManager test page"
    case loadUITestPagePlayground = "Load HTML playground"
    case loadUITestPageAlerts = "Load JS/Native alert panels"
    case loadUITestPageMedia = "Load Media test page"
    case separatorC
    case insertTextInCurrentNote = "Insert text in current note"
    case create100Notes = "Create 100 random notes"
    case setAutoUpdateToMock = "Set autoupdate to mock"
}
