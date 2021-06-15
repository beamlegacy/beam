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
    case loadUITestPage4 = "Load PasswordManager test page"
    case separatorC
    case insertTextInCurrentNote = "Insert text in current note"
}
