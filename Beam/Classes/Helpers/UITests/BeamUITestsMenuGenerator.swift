import Foundation
import BeamCore
import AutoUpdate
import MockHttpServer
import Fakery

// swiftlint:disable file_length type_body_length
class BeamUITestsMenuGenerator {
    static var beeper: CrossTargetBeeper?
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func executeCommand(_ command: UITestMenuAvailableCommands) {
        switch command {
        case .populateDBWithJournal: populateWithJournalNote(count: 10)
        case .populatePasswordsDB: populatePasswordsDB()
        case .populateCreditCardsDB: populateCreditCardsDB()
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
        case .loadUITestSVG: loadUITestsPage(identifier: "SVG")
        case .insertTextInCurrentNote: insertTextInCurrentNote()
        case .create100Notes: Self.createNotes(count: 100, journalRatio: 0.2, futureRatio: 0.1)
        case .create100NormalNotes: Self.createNotes(count: 100, journalRatio: 0.0, futureRatio: 0.0)
        case .create100JournalNotes: Self.createNotes(count: 100, journalRatio: 1.0, futureRatio: 0.05)
        case .create10Notes: Self.createNotes(count: 10, journalRatio: 0.2, futureRatio: 0.05)
        case .create10NormalNotes: Self.createNotes(count: 10, journalRatio: 0.0, futureRatio: 0.0)
        case .create10JournalNotes: Self.createNotes(count: 10, journalRatio: 1.0, futureRatio: 0.05)
        case .create1000Links: Self.createLinks(count: 1000)
        case .create10000Links: Self.createLinks(count: 10000)
        case .create50000Links: Self.createLinks(count: 50000)
        case .setAutoUpdateToMock: setAutoUpdateToMock()
        case .cleanDownloads: cleanDownloadFolder()
        case .omniboxFillHistory: fillHistory()
        case .omniboxEnableSearchInHistoryContent: omniboxEnableSearchInHistoryContent()
        case .omniboxDisableSearchInHistoryContent: omniboxDisableSearchInHistoryContent()
        case .signInWithTestAccount: signInWithTestAccount()
        case .signUpWithRandomTestAccount: signUpWithRandomTestAccount()
        case .showWebViewCount: showWebViewCount()
        case .showOnboarding: showOnboarding()
        case .resetCollectAlert: resetCollectAlert()
        case .clearPasswordsDB: clearPasswordsDatabase()
        case .clearCreditCardsDB: clearCreditCardsDatabase()
        case .startMockHttpServer: startMockHttpServer()
        case .stopMockHttpServer: stopMockHttpServer()
        case .enableCreateJournalOnce: enableCreateJournalOnce()
        case .disableCreateJournalOnce: disableCreateJournalOnce()
        case .deletePrivateKeys: deletePrivateKeys()
        case .deleteAllRemoteObjects: deleteAllRemoteObjects()
        case .resetAPIEndpoints: connectToProductionServer()
        case .setAPIEndpointsToStaging: connectToStagingServer()
        case .deleteRemoteAccount: deleteRemoteAccount()
        case .createFakeDailySummary: createFakeDailySummary()
        case .createNote: createNote()
        case .createAndOpenNote: createNote(open: true)
        case .createPublishedNote: createPublishedNote()
        case .createAndOpenPublishedNote: createPublishedNote(open: true)
        default: break
        }
    }

    var documentManager = DocumentManager()
    var googleCalendarService = GoogleCalendarService(accessToken: nil, refreshToken: nil)

    private func logout() {
        for window in AppDelegate.main.windows {
            window.state.closeAllTabs(closePinnedTabs: true)
        }
        AccountManager.logout()
        AppDelegate.main.deleteAllLocalData()
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

        newNote.save(completion: { result in
            switch result {
            case .failure(let error):
                Logger.shared.logError(error.localizedDescription, category: .general)
            case .success(let success):
                Logger.shared.logInfo("Saved! \(success)", category: .documentDebug)
            }
        })
    }

    private func destroyDatabase() {
        clearPasswordsDatabase()
        clearCreditCardsDatabase()
        DocumentManager().deleteAll { _ in }
        DatabaseManager().deleteAll { _ in }
        let data = AppDelegate.main.window?.state.data
        LinkStore.shared.deleteAll(includedRemote: false) { _ in }
        RestoreTabsManager.shared.clearSavedClosedTabs()
        PinnedBrowserTabsManager().savePinnedTabs(tabs: [])
        ContentBlockingManager.shared.radBlockPreferences.removeAllEntries { }
        try? GRDBDatabase.shared.clear()
        data?.saveData()
    }

    private func loadUITestsPage(identifier: String) {
        if let localUrl = Bundle.main.url(forResource: "UITests-\(identifier)", withExtension: "html", subdirectory: nil) {
            _ = AppDelegate.main.window?.state.createTab(withURLRequest: URLRequest(url: localUrl), originalQuery: nil)
        }
    }

    private func populateWithJournalNote(count: Int) {
        let generator = FakeNoteGenerator(count: count, journalRatio: 1, futureRatio: 0)
        generator.generateNotes()
        for note in generator.notes {
            note.save()
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

    private func populateCreditCardsDB() {
        let creditCards = [
            CreditCardEntry(cardDescription: "John's personal Visa", cardNumber: "4701234567890123", cardHolder: "John Appleseed", expirationMonth: 4, expirationYear: 2025),
            CreditCardEntry(cardDescription: "Jane's company Amex", cardNumber: "374912345678910", cardHolder: "Jane Appleseed", expirationMonth: 8, expirationYear: 2024)
        ]
        for creditCard in creditCards {
            CreditCardAutofillManager.shared.save(entry: creditCard)
        }
    }

    private func todaysName(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.doesRelativeDateFormatting = false
        fmt.timeStyle = .none
        return fmt.string(from: date)
    }

    static public func createLinks(count: Int = 50000) {
        let random = (try? BeamDate.now.description.MD5()) ?? "random_failed"

        for index in 1...count {
            _ = LinkStore.shared.getOrCreateId(for: "http://beamapp.co/test/\(index)/\(random)", title: "Title \(index) \(random)")
        }

        Logger.shared.logDebug("Created \(count) links", category: .linkDB)
    }

    static public func createNotes(count: Int, journalRatio: Float, futureRatio: Float) {
        let generator = FakeNoteGenerator(count: count, journalRatio: journalRatio, futureRatio: futureRatio)
        generator.generateNotes()
        for note in generator.notes {
            note.save()
        }
    }

    private func setAutoUpdateToMock() {
        let appDel = AppDelegate.main
        let checker = VersionChecker(mockedReleases: AppRelease.mockedReleases(), autocheckEnabled: true)
        checker.logMessage = {
            Logger.shared.logInfo($0, category: .autoUpdate)
        }
        appDel.window?.state.objectWillChange.send()
        appDel.data.versionChecker = checker
    }

    private func cleanDownloadFolder() {
        guard let downloadUrl = DownloadFolder(rawValue: PreferencesManager.selectedDownloadFolder)?.sandboxAccessibleUrl else { return }
        let fileManager = FileManager.default
        guard let content = try? fileManager.contentsOfDirectory(atPath: downloadUrl.path) else { return }

        let elementToDelete = content.filter { $0.hasSuffix("SF-Symbols-3.dmg") || $0.hasSuffix("SF-Symbols-3.dmg.beamdownload") }
        elementToDelete.forEach { try? fileManager.removeItem(at: downloadUrl.appendingPathComponent($0)) }
    }

    private func fillHistory(longTitle: Bool = false) {
        addPageToHistory(url: "https://fr.wikipedia.org/wiki/Hello_world", title: "Hello world")
        addPageToHistory(url: "https://en.wikipedia.org/wiki/Hubert_Blaine_Wolfeschlegelsteinhausenbergerdorff_Sr.",
                         title: "Hubert Blaine Wolfeschlegelsteinhausenbergerdorff Sr.")
        addPageToHistory(url: "https://www.google.com/search?q=Beam%20the%20best%20browser&client=safari", title: "Beam the best browser")
        addPageToHistory(url: "https://beamapp.co", aliasUrl: "https://alternateurl.com", title: "Beam")
    }

    private func omniboxEnableSearchInHistoryContent() {
        PreferencesManager.includeHistoryContentsInOmniBox = true
    }

    private func omniboxDisableSearchInHistoryContent() {
        PreferencesManager.includeHistoryContentsInOmniBox = false
    }

    private func addPageToHistory(url: String, aliasUrl: String? = nil, title: String) {
        _ = IndexDocument(source: url, title: title, contents: title)
        let id: UUID = {
            if let alias = aliasUrl {
                return BeamLinkDB.shared.visitId(alias, title: title, content: title, destination: url)
            }
            return BeamLinkDB.shared.visitId(url, title: title, content: title)
        }()
        let frecency = FrecencyUrlRecord(urlId: id, lastAccessAt: BeamDate.now, frecencyScore: 1, frecencySortScore: 1, frecencyKey: AutocompleteManager.urlFrecencyParamKey)
        try? GRDBDatabase.shared.saveFrecencyUrl(frecency)
    }

    private func signInWithTestAccount() {
        guard !AuthenticationManager.shared.isAuthenticated else { return }

        let accountManager = AccountManager()
        let email = Configuration.testAccountEmail
        let password = Configuration.testAccountPassword
        try? EncryptionManager.shared.replacePrivateKey(for: Configuration.testAccountEmail, with: Configuration.testPrivateKey)

        accountManager.signIn(email: email, password: password, runFirstSync: true, completionHandler: { result in
            if case .failure(let error) = result {
                fatalError(error.localizedDescription)
            }
        })
    }

    // swiftlint:disable:next function_body_length
    private func signUpWithRandomTestAccount() {
        guard !AuthenticationManager.shared.isAuthenticated else {
            showAlert("Already authenticated", "You are already authenticated")
            return
        }

        let accountManager = AccountManager()
        let randomString = UUID()
        let emailComponents = Configuration.testAccountEmail.split(separator: "@")
        let email = "\(emailComponents[0])_\(randomString)@\(emailComponents[1])"
        let username = "\(emailComponents[0])_\(randomString)".replacingOccurrences(of: "+", with: "_").substring(from: 0, to: 30)
        let password = Configuration.testAccountPassword

        accountManager.signUp(email, password) { result in
            if case .failure(let error) = result {
                DispatchQueue.main.async {
                    self.showAlert("Cannot sign up", "Cannot sign up with \(email): \(error.localizedDescription)")
                }
                return
            }
            accountManager.signIn(email: email, password: password, runFirstSync: false, completionHandler: { result in
                if case .failure(let error) = result {
                    DispatchQueue.main.async {
                        self.showAlert("Cannot sign in", "Cannot sign in with \(email): \(error.localizedDescription)")
                    }
                } else {
                    accountManager.setUsername(username: username) { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .failure(let error):
                                let errorMessage: String?
                                if case APIRequestError.apiErrors(let errorable) = error, let firstError = errorable.errors?.first {
                                    errorMessage = firstError.message
                                } else {
                                    errorMessage = error.localizedDescription
                                }
                                if let errorMessage = errorMessage {
                                    self.showAlert("Cannot set username \(username)", errorMessage)
                                }
                            case .success:
                                if AppDelegate.main.data.onboardingManager.needsToDisplayOnboard {
                                    AppDelegate.main.data.onboardingManager.userDidSignUp = true
                                    AppDelegate.main.data.onboardingManager.advanceToNextStep(OnboardingStep(type: .imports))
                                    AppDelegate.main.data.onboardingManager.advanceToNextStep()
                                }
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(email, forType: .string)

                                accountManager.runFirstSync(useBuiltinPrivateKeyUI: false)
                            }
                        }
                    }
                }
            })
        }
    }

    private func showAlert(_ title: String, _ content: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = content
        alert.addButton(withTitle: "Dismiss Alert")
        alert.runModal()
    }

    private func showWebViewCount() {
        #if TEST || DEBUG
        let alert = NSAlert()
        alert.messageText = "Leak Helper"
        alert.informativeText = "WebViews alives:\(BeamWebView.aliveWebViewsCount)"
        alert.addButton(withTitle: "Dismiss Alert")

        // Display the NSAlert
        alert.runModal()
        #endif
    }

    private func showOnboarding() {
        logout()
        clearPasswordsDatabase()
        AuthenticationManager.shared.username = nil
        let onboarding = AppDelegate.main.window?.state.data.onboardingManager
        onboarding?.forceDisplayOnboarding()
        AppDelegate.main.windows.forEach { window in
            window.close()
        }
        AppDelegate.main.createWindow(frame: nil, restoringTabs: false)
    }

    private func clearPasswordsDatabase() {
        PasswordManager.shared.deleteAll(includedRemote: false)
    }

    private func clearCreditCardsDatabase() {
        CreditCardAutofillManager.shared.deleteAll(includedRemote: false)
    }

    private func startMockHttpServer() {
        MockHttpServer.start(port: 8080)
    }

    private func stopMockHttpServer() {
        MockHttpServer.stop()
    }

    private func resetCollectAlert() {
        PreferencesManager.isCollectFeedbackEnabled = true
        PreferencesManager.showsCollectFeedbackAlert = true
    }

    private func enableCreateJournalOnce() {
        PreferencesManager.createJournalOncePerWindow = true
    }

    private func disableCreateJournalOnce() {
        PreferencesManager.createJournalOncePerWindow = false
        // Destroy the cached journal view if needed
        for window in AppDelegate.main.windows {
            window.state.cachedJournalStackView = nil
            window.state.cachedJournalScrollView = nil
        }
    }

    private func deletePrivateKeys() {
        Persistence.Encryption.privateKeys = nil
        Persistence.Encryption.updateDate = BeamDate.now
    }

    private func deleteAllRemoteObjects() {
        _ = try? BeamObjectManager().deleteAll(nil) { _ in
            DispatchQueue.main.async {
                AppDelegate.main.deleteAllLocalData()
            }
        }
    }

    private func connectToStagingServer() {
        for window in AppDelegate.main.windows {
            window.state.closeAllTabs(closePinnedTabs: true)
        }
        Configuration.setAPIEndPointsToStaging()
        AppDelegate.main.deleteAllLocalData()
    }

    private func connectToProductionServer() {
        for window in AppDelegate.main.windows {
            window.state.closeAllTabs(closePinnedTabs: true)
        }
        Configuration.reset()
        AppDelegate.main.deleteAllLocalData()
    }

    private func deleteRemoteAccount() {
        AccountManager().deleteAccount { result in
            switch result {
            case .failure(let error):
                Logger.shared.logError("Error while deleting account: \(error)", category: .accountManager)
            case .success:
                Logger.shared.logDebug("Account deleted", category: .accountManager)
            }
        }
    }

    private func createFakeDailySummary() {
        let now = BeamDate.now
        let cal = Calendar(identifier: .iso8601)
        let sem = DispatchSemaphore(value: 0)

        guard let pastday = cal.date(byAdding: .day, value: -2, to: now) else { return }
        BeamDate.freeze(pastday)
        let pastdayNotes: [BeamNote] = createNotes(with: ["Alpha Wann", "Prince Waly"])

        guard let yesterday = cal.date(byAdding: .day, value: -1, to: now) else { return }
        BeamDate.freeze(yesterday)
        createNotes(with: ["Key Glock", "Maxo Kream"])

        let urlsAndTitlesYesterday = [
            ("https://twitter.com", "Twitter"),
            ("http://lemonde.fr/", "LeMonde")
        ]
        createFakeDailyUrl(for: urlsAndTitlesYesterday)

        BeamDate.reset()
        createNotes(with: ["Triplego", "Laylow"])

        for pastdayNote in pastdayNotes {
            pastdayNote.recordScoreWordCount()
            pastdayNote.addChild(BeamElement("Some text"))
            pastdayNote.save(completion: { _ in sem.signal() })
            sem.wait()
        }

        let urlsAndTitlesToday = [
            ("https://pitchfork.com", "Pitchfork"),
            ("https://ra.co", "RA Electronic music online")
        ]
        createFakeDailyUrl(for: urlsAndTitlesToday)
    }

    @discardableResult
    private func createNotes(with titles: [String]) -> [BeamNote] {
        let faker = Faker(locale: "en-US")
        let text = BeamText(text: faker.company.bs())
        var notes: [BeamNote] = []

        for title in titles {
            let note = BeamNote(title: title)
            note.type = .note
            note.children.append(BeamElement(text))
            note.save()
            notes.append(note)
        }
        return notes
    }

    private func createFakeDailyUrl(for urlAndTitles: [(String, String)]) {
        let storage = GRDBDailyUrlScoreStore()

        let urlIdsToday: [UUID] = urlAndTitles.map {
            return LinkStore.shared.visit($0.0, title: $0.1, content: nil, destination: nil).id
        }
        for (index, urlId) in urlIdsToday.enumerated() {
            storage.apply(to: urlId) { $0.readingTimeToLastEvent = 100 + Double(index)}
        }
    }

    var noteCount = 1
    @discardableResult
    private func createNote(open: Bool = false) -> BeamNote {
        let note = BeamNote(title: "Test\(noteCount)")
        note.type = .note
        note.save()
        noteCount += 1
        if open {
            self.open(note: note)
        }
        return note
    }

    private func createPublishedNote(open: Bool = false) {
        let note = createNote()
        BeamNoteSharingUtils.makeNotePublic(note, becomePublic: true, completion: { _ in
            if open {
                DispatchQueue.main.async {
                    self.open(note: note)
                }
            }
        })
    }

    private func open(note: BeamNote) {
        AppDelegate.main.window?.state.mode = .note
        AppDelegate.main.window?.state.currentNote = note
    }
}
