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
    case loadUITestPage = "Load UITests Page"
}
