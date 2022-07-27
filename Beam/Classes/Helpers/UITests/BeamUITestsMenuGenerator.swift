import Foundation
import BeamCore
import AutoUpdate
import MockHttpServer
import Fakery

struct BeamUITestsMenuGeneratorSource: BeamDocumentSource {
    static var sourceId: String { "\(Self.self)" }
}

// swiftlint:disable file_length type_body_length
class BeamUITestsMenuGenerator: BeamDocumentSource {
    static var sourceId: String { "\(Self.self)" }

    static var beeper: CrossTargetBeeper?
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func executeCommand(_ command: UITestMenuAvailableCommands) {
        switch command {
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
        case .createTabGroup: createTabGroup(named: false)
        case .createTabGroupNamed: createTabGroup(named: true)
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
        case .omniboxEnableSearchInHistoryContent: omniboxSetEnableSearchInHistoryContent(enabled: true)
        case .omniboxDisableSearchInHistoryContent: omniboxSetEnableSearchInHistoryContent(enabled: false)
        case .signInWithTestAccount: signInWithTestAccount()
        case .signUpWithRandomTestAccount: signUpWithRandomTestAccount()
        case .showWebViewCount: showWebViewCount()
        case .showOnboarding: showOnboarding()
        case .resetCollectAlert: resetCollectAlert()
        case .clearPasswordsDB: clearPasswordsDatabase()
        case .clearCreditCardsDB: clearCreditCardsDatabase()
        case .startMockHttpServer: startMockHttpServer()
        case .stopMockHttpServer: stopMockHttpServer()
        case .enableCreateJournalOnce: setCreateJournalOnce(enabled: true)
        case .disableCreateJournalOnce: setCreateJournalOnce(enabled: false)
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
        case .startBeamOnTabs: setStartBeamOn(.webTabs)
        case .startBeamOnDefault: setStartBeamOn(nil)
        case .populateDBWithJournal: populateWithJournalNote(count: 10)
        case .populatePasswordsDB: populatePasswordsDB()
        case .populateCreditCardsDB: populateCreditCardsDB()
        case .disablePasswordProtect: disablePasswordProtection()
        default: break
        }
    }

    var googleCalendarService = GoogleCalendarService(accessToken: nil, refreshToken: nil)

    private func logout() {
        for window in AppDelegate.main.windows {
            window.state.closeAllTabs(closePinnedTabs: true)
        }
        BeamData.shared.currentAccount?.logout()
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

        _ = newNote.save(self)
    }

    private func destroyDatabase() {
        clearPasswordsDatabase()
        clearCreditCardsDatabase()

        try? BeamData.shared.currentDocumentCollection?.delete(self, filters: [])
        LinkStore.shared.deleteAll(includedRemote: false) { _ in }
        AppDelegate.main.deleteSessionData()
        PinnedBrowserTabsManager().savePinnedTabs(tabs: [])
        ContentBlockingManager.shared.radBlockPreferences.removeAllEntries { }
        KeychainDailyNoteScoreStore.shared.clear()
        try? BeamData.shared.clearAllAccountsAndSetupDefaultAccount()
    }

    private func urlForTestPage(identifier: String) -> URL? {
        Bundle.main.url(forResource: "UITests-\(identifier)",
                        withExtension: "html", subdirectory: nil)
    }

    @discardableResult
    private func loadUITestsPage(identifier: String, setCurrent: Bool = true) -> BrowserTab? {
        guard let localUrl = urlForTestPage(identifier: identifier) else { return nil }
        return AppDelegate.main.window?.state.createTab(withURLRequest: URLRequest(url: localUrl),
                                                        originalQuery: nil, setCurrent: setCurrent)
    }

    private func populateWithJournalNote(count: Int) {
        let generator = FakeNoteGenerator(count: count, journalRatio: 1, futureRatio: 0)
        generator.generateNotes()
        for note in generator.notes {
            _ = note.save(BeamUITestsMenuGeneratorSource())
        }
    }

    private func populatePasswordsDB() {
        guard let url = Bundle.main.url(forResource: "UITests-Passwords", withExtension: "csv") else {
            Logger.shared.logError("Passwords.csv file not found in E2ETests/PasswordManager", category: .general)
            return
        }
        do {
            _ = try PasswordImporter.importPasswords(fromCSV: url)
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

    private func disablePasswordProtection() {
        // Temporarily disable device authentication to access password and credit cards
        DeviceAuthenticationManager.shared.temporarilyDisableDeviceAuthenticationProtection()
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
            _ = note.save(BeamUITestsMenuGeneratorSource())
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

        Task {
            await appDel.data.versionChecker.performUpdateIfAvailable()
        }
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

    private func addPageToHistory(url: String, aliasUrl: String? = nil, title: String) {
        _ = IndexDocument(source: url, title: title, contents: title)
        let id: UUID = {
            if let alias = aliasUrl {
                return BeamLinkDB.shared.visitId(alias, title: title, content: title, destination: url)
            }
            return BeamLinkDB.shared.visitId(url, title: title, content: title)
        }()
        let frecency = FrecencyUrlRecord(urlId: id, lastAccessAt: BeamDate.now, frecencyScore: 1, frecencySortScore: 1, frecencyKey: AutocompleteManager.urlFrecencyParamKey)
        try? BeamData.shared.urlHistoryManager?.saveFrecencyUrl(frecency)
    }

    private func signInWithTestAccount() {
        guard !AuthenticationManager.shared.isAuthenticated else { return }

        let email = Configuration.testAccountEmail
        let password = Configuration.testAccountPassword
        try? EncryptionManager.shared.replacePrivateKey(for: Configuration.testAccountEmail, with: Configuration.testPrivateKey)

        BeamData.shared.currentAccount?.signIn(email: email, password: password, runFirstSync: true, completionHandler: { result in
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

        let randomString = UUID()
        let emailComponents = Configuration.testAccountEmail.split(separator: "@")
        let email = "\(emailComponents[0])_\(randomString)@\(emailComponents[1])"
        let username = "\(emailComponents[0])_\(randomString)".replacingOccurrences(of: "+", with: "_").substring(from: 0, to: 30)
        let password = Configuration.testAccountPassword

        BeamData.shared.currentAccount?.signUp(email, password) { result in
            if case .failure(let error) = result {
                DispatchQueue.main.async {
                    self.showAlert("Cannot sign up", "Cannot sign up with \(email): \(error.localizedDescription)")
                }
                return
            }
            BeamData.shared.currentAccount?.signIn(email: email, password: password, runFirstSync: false, completionHandler: { result in
                if case .failure(let error) = result {
                    DispatchQueue.main.async {
                        self.showAlert("Cannot sign in", "Cannot sign in with \(email): \(error.localizedDescription)")
                    }
                } else {
                    BeamData.shared.currentAccount?.setUsername(username: username) { result in
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
                                if BeamData.shared.onboardingManager.needsToDisplayOnboard {
                                    BeamData.shared.onboardingManager.userDidSignUp = true
                                    BeamData.shared.onboardingManager.advanceToNextStep(OnboardingStep(type: .imports))
                                    BeamData.shared.onboardingManager.advanceToNextStep()
                                }
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(email, forType: .string)

                                BeamData.shared.currentAccount?.runFirstSync(useBuiltinPrivateKeyUI: false)
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
        AppDelegate.main.createWindow(frame: nil)
    }

    private func clearPasswordsDatabase() {
        PasswordManager.shared.deleteAll(includedRemote: false)
    }

    private func clearCreditCardsDatabase() {
        CreditCardAutofillManager.shared.deleteAll(includedRemote: false)
    }

    private func startMockHttpServer() {
        MockHttpServer.start(port: Configuration.MockHttpServer.port)
    }

    private func stopMockHttpServer() {
        MockHttpServer.stop()
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
        BeamData.shared.currentAccount?.deleteAccount { result in
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

        guard let pastday = cal.date(byAdding: .day, value: -2, to: now) else { return }
        BeamDate.freeze(pastday)
        let pastdayNotes: [BeamNote] = createNotes(with: ["Alpha Wann", "Prince Waly"])

        guard let yesterday = cal.date(byAdding: .day, value: -1, to: now) else { return }
        BeamDate.freeze(yesterday)
        createNotes(with: ["Key Glock", "Maxo Kream"])

        let urlsAndTitlesYesterday = [
            ("https://twitter.com/home", "Twitter"),
            ("http://lemonde.fr/international/", "LeMonde")
        ]
        createFakeDailyUrl(for: urlsAndTitlesYesterday)

        BeamDate.reset()
        createNotes(with: ["Triplego", "Laylow"])

        for pastdayNote in pastdayNotes {
            pastdayNote.recordScoreWordCount()
            pastdayNote.addChild(BeamElement("Some text"))
            _ = pastdayNote.save(self)
        }

        let urlsAndTitlesToday = [
            ("https://pitchfork.com/contact/", "Pitchfork"),
            ("https://ra.co/events/fr/paris", "RA Electronic music online")
        ]
        createFakeDailyUrl(for: urlsAndTitlesToday)
    }

    @discardableResult
    private func createNotes(with titles: [String]) -> [BeamNote] {
        let faker = Faker(locale: "en-US")
        let text = BeamText(text: faker.company.bs())
        var notes: [BeamNote] = []

        for title in titles {
            // swiftlint:disable:next force_try
            let note = try! BeamNote(title: title)
            note.type = .note
            note.owner = BeamData.shared.currentDatabase
            note.children.append(BeamElement(text))
            _ = note.save(self)
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
            storage.apply(to: urlId) {
                $0.readingTimeToLastEvent = 100 + (Double(index) * 10)
                $0.textAmount = 1000 + index
                $0.scrollRatioY = 100 + (Float(index) * 10)
            }
        }
    }

    var noteCount = 1
    @discardableResult
    private func createNote(open: Bool = false) -> BeamNote {
        // swiftlint:disable:next force_try
        let note = try! BeamNote(title: "Test\(noteCount)")
        note.type = .note
        note.owner = BeamData.shared.currentDatabase
        _ = note.save(self)
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

// MARK: - Tab Group
extension BeamUITestsMenuGenerator {
    private func createTabGroup(named: Bool) {
        guard let tabsManager = AppDelegate.main.window?.state.browserTabsManager else { return }
        let pagesToOpen = ["1", "2", "3", "4"]
        let tabs = pagesToOpen.compactMap { identifier in
            loadUITestsPage(identifier: identifier, setCurrent: false)
        }

        var title: String?
        if named {
            let existingGroups = Set(tabsManager.tabGroupingManager.builtPagesGroups.values)
            var index = 1
            title = "Test\(index)"
            while existingGroups.contains(where: { $0.title == title }) {
                index += 1
                title = "Test\(index)"
            }
        }
        let group = TabGroup(pageIds: [], title: title)
        tabs.forEach { tab in
            tabsManager.moveTabToGroup(tab.id, group: group)
        }
    }
}

// MARK: - Preferences toggles
extension BeamUITestsMenuGenerator {

    private func setStartBeamOn(_ value: PreferencesManager.PreferencesDefaultWindowMode?) {
        PreferencesManager.defaultWindowMode = value ?? .journal
    }

    private func setBrowsingSessionCollection(_ value: Bool) {
        PreferencesManager.browsingSessionCollectionIsOn = value
    }

    private func omniboxSetEnableSearchInHistoryContent(enabled: Bool) {
        PreferencesManager.includeHistoryContentsInOmniBox = enabled
    }

    private func resetCollectAlert() {
        PreferencesManager.isCollectFeedbackEnabled = true
        PreferencesManager.showsCollectFeedbackAlert = true
    }

    private func setCreateJournalOnce(enabled: Bool) {
        PreferencesManager.createJournalOncePerWindow = enabled
        if !enabled {
            // Destroy the cached journal view if needed
            for window in AppDelegate.main.windows {
                window.state.cachedJournalStackView = nil
                window.state.cachedJournalScrollView = nil
            }
        }
    }

}
