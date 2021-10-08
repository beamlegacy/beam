import Foundation
import Fakery
import BeamCore
import AutoUpdate

import SwiftUI // Remove once we remove .testMeetingModal menu

class BeamUITestsMenuGenerator {
    // swiftlint:disable:next cyclomatic_complexity
    func executeCommand(_ command: UITestMenuAvailableCommands) {
        switch command {
        case .populateDBWithJournal: populateWithJournalNote(count: 10)
        case .populatePasswordsDB: populatePasswordsDB()
        case .destroyDB: destroyDatabase()
        case .logout: logout()
        case .deleteLogs: deleteLogs()
        case .resizeWindowLandscape: resizeWindowLandscape()
        case .resizeWindowPortrait: resizeWindowPortrait()
        case .resizeSquare1000: resizeSquare1000()
        case .enableBrowsingSessionCollection: setBrowsingSessionCollection(true)
        case .disableBrowsingSessionCollection: setBrowsingSessionCollection(false)
        case .loadUITestPage1: loadUITestsPage(identifier: "1")
        case .loadUITestPage2: loadUITestsPage(identifier: "2")
        case .loadUITestPage3: loadUITestsPage(identifier: "3")
        case .loadUITestPage4: loadUITestsPage(identifier: "4")
        case .loadUITestPagePassword: loadUITestsPage(identifier: "Password")
        case .loadUITestPagePlayground: loadUITestsPage(identifier: "Playground")
        case .loadUITestPageAlerts: loadUITestsPage(identifier: "Alerts")
        case .loadUITestPageMedia: loadUITestsPage(identifier: "Media")
        case .insertTextInCurrentNote: insertTextInCurrentNote()
        case .create100Notes: Self.create100Notes()
        case .setAutoUpdateToMock: setAutoUpdateToMock()
        case .cleanDownloads: cleanDownloadFolder()
        case .omnibarFillHistory: fillHistory()
        case .signInWithTestAccount: signInWithTestAccount()
        case .testMeetingModal: testAddMeeting()
        default: break
        }
    }

    var documentManager = DocumentManager()

    private func logout() {
        AccountManager.logout()
    }

    private func deleteLogs() {
        Logger.shared.removeFiles()
    }

    private func resizeWindowPortrait() {
        AppDelegate.main.resizeWindow(width: 800)
    }

    private func resizeWindowLandscape() {
        AppDelegate.main.resizeWindow(width: 1200)
    }

    private func resizeSquare1000() {
        AppDelegate.main.resizeWindow(width: 1000, height: 1000)
    }

    private func setBrowsingSessionCollection(_ value: Bool) {
        PreferencesManager.browsingSessionCollectionIsOn = value
    }

    private func insertTextInCurrentNote() {
        guard let currentNote = AppDelegate.main.window?.state.currentNote ?? (AppDelegate.main.window?.firstResponder as? BeamTextEdit)?.rootNode?.note else {
            Logger.shared.logDebug("Current note is nil", category: .general)

            return
        }
        Logger.shared.logDebug("Inserting text in current note", category: .documentDebug)

        guard let newNote = currentNote.deepCopy(withNewId: false, selectedElements: nil, includeFoldedChildren: false) else {
            Logger.shared.logError("Unable to create deep copy of note \(currentNote)", category: .document)
            return
        }

        for index in 0...3 {
            newNote.addChild(BeamElement("test \(index): \(BeamDate.now.description)"))
        }

        Logger.shared.logDebug("current Note: \(currentNote.id) copy: \(newNote.id)", category: .documentDebug)

        newNote.save(documentManager: documentManager) { result in
            switch result {
            case .failure(let error):
                Logger.shared.logError(error.localizedDescription, category: .general)
            case .success(let success):
                Logger.shared.logInfo("Saved! \(success)", category: .documentDebug)
            }
        }
    }

    private func destroyDatabase() {
        DocumentManager().deleteAll { _ in }
        DatabaseManager().deleteAll { _ in }
        let data = AppDelegate.main.window?.state.data
        try? LinkStore.shared.deleteAll()
        data?.linkManager.deleteAllLinks()
        try? GRDBDatabase.shared.clear()
        data?.saveData()
    }

    private func loadUITestsPage(identifier: String) {
        if let localUrl = Bundle.main.url(forResource: "UITests-\(identifier)", withExtension: "html", subdirectory: nil) {
            _ = AppDelegate.main.window?.state.createTab(withURL: localUrl, originalQuery: nil)
        }
    }

    private func populateWithJournalNote(count: Int) {
        let documentManager = DocumentManager()
        let generator = FakeNoteGenerator(count: count, journalRatio: 1, futureRatio: 0)
        generator.generateNotes()
        for note in generator.notes {
            note.save(documentManager: documentManager)
        }
    }

    private func populatePasswordsDB() {
        guard let url = Bundle.main.url(forResource: "UITests-Passwords", withExtension: "csv") else {
            Logger.shared.logError("Passwords.csv file not found in E2ETests/PasswordManager", category: .general)
            return
        }
        do {
            try PasswordImporter.importPasswords(fromCSV: url)
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .passwordManager)
        }
    }

    private func todaysName(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.doesRelativeDateFormatting = false
        fmt.timeStyle = .none
        return fmt.string(from: date)
    }

    static public func create100Notes() {
        let documentManager = DocumentManager()
        let generator = FakeNoteGenerator(count: 100, journalRatio: 0.2, futureRatio: 0.1)
        generator.generateNotes()
        for note in generator.notes {
            note.save(documentManager: documentManager)
        }
    }

    private func setAutoUpdateToMock() {
        let appDel = AppDelegate.main
        let checker = VersionChecker(mockedReleases: AppRelease.mockedReleases(), autocheckEnabled: true)
        appDel.data.versionChecker = checker

        checker.checkForUpdates()
    }

    private func cleanDownloadFolder() {
        guard let downloadUrl = DownloadFolder(rawValue: PreferencesManager.selectedDownloadFolder)?.sandboxAccessibleUrl else { return }
        let fileManager = FileManager.default
        guard let content = try? fileManager.contentsOfDirectory(atPath: downloadUrl.path) else { return }

        let elementToDelete = content.filter { $0.hasSuffix("SF-Symbols-3.dmg") || $0.hasSuffix("SF-Symbols-3.dmg.beamdownload") }
        elementToDelete.forEach { try? fileManager.removeItem(at: downloadUrl.appendingPathComponent($0)) }
    }

    private func fillHistory(longTitle: Bool = false) {
        addPageToHistory(url: "https://fr.wikipedia.org/wiki/Hello_world", title: "Hello world", id: 1)
        addPageToHistory(url: "https://en.wikipedia.org/wiki/Hubert_Blaine_Wolfeschlegelsteinhausenbergerdorff_Sr.",
                         title: "Hubert Blaine Wolfeschlegelsteinhausenbergerdorff Sr.", id: 2)
        addPageToHistory(url: "https://www.google.com/search?q=Beam%20the%20best%20browser&client=safari", title: "Beam the best browser", id: 3)
    }

    private func addPageToHistory(url: String, title: String, id: Int) {
        _ = IndexDocument(source: url, title: title, contents: title)
        try? GRDBDatabase.shared.insertHistoryUrl(urlId: UInt64(id), url: url, title: title, content: title)
    }

    private func signInWithTestAccount() {
        guard !AuthenticationManager.shared.isAuthenticated else { return }

        let accountManager = AccountManager()
        let email = Configuration.testAccountEmail
        let password = Configuration.testAccountPassword

        accountManager.signIn(email, password) { result in
            if case .failure(let error) = result {
                fatalError(error.localizedDescription)
            }
        }
    }
    private func addMeeting(_ meeting: Meeting, to note: BeamNote) {
        guard let documentManager = AppDelegate.main.window?.state.data.documentManager else { return }
        var text = BeamText(text: "")
        var meetingAttributes: [BeamText.Attribute] = []
        if meeting.linkCards {
            let meetingNote = BeamNote.fetchOrCreate(documentManager, title: meeting.name)
            meetingAttributes = [.internalLink(meetingNote.id)]
        }
        text.insert(meeting.name, at: 0, withAttributes: meetingAttributes)

        if !meeting.attendees.isEmpty {
            let prefix = "Meeting with "
            var position = prefix.count
            text.insert(prefix, at: 0, withAttributes: [])
            meeting.attendees.enumerated().forEach { index, attendee in
                let name = attendee.name
                let attendeeNote = BeamNote.fetchOrCreate(documentManager, title: name)
                text.insert(name, at: position, withAttributes: [.internalLink(attendeeNote.id)])
                position += name.count
                if index < meeting.attendees.count - 1 {
                    let separator = ", "
                    text.insert(separator, at: position, withAttributes: [])
                    position += separator.count
                }
            }
            text.insert(" for ", at: position, withAttributes: [])
        }
        let e = BeamElement(text)
        note.insert(e, after: note.children.last)
    }

    private func testAddMeeting() {
        let state = AppDelegate.main.window?.state
        let model = MeetingModalView.ViewModel(meetingName: "Meeting Integration",
                                               attendees: [
                                                Meeting.Attendee(email: "luis@beamapp.co", name: "Luis Darmon"),
                                                Meeting.Attendee(email: "dom@beamapp.co", name: "Dom Leca"),
                                                Meeting.Attendee(email: "remi@beamapp.co", name: "Remi Santos")
                                               ],
                                               onFinish: { [weak self] meeting in
                                                if let meeting = meeting, let note = state?.data.todaysNote {
                                                    self?.addMeeting(meeting, to: note)
                                                }
                                                state?.overlayViewModel.modalView = nil
                                               })
        state?.overlayViewModel.modalView = AnyView(MeetingModalView(viewModel: model))
    }

}
