//
//  UITestsMenuBar.swift
//  BeamUITests
//
//  Created by Andrii on 26.07.2021.
//

import Foundation
import XCTest

class UITestsMenuBar: BaseMenuBar {
    
    let beeper: CrossTargetBeeper = CrossTargetNotificationCenterBeeper()
    
    @discardableResult
    func destroyDB() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.destroyDB.rawValue)
        return self
    }
    
    @discardableResult
    func startMockHTTPServer() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.startMockHttpServer.rawValue)
        return self
    }
    
    @discardableResult
    func stopMockHTTPServer() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.stopMockHttpServer.rawValue)
        return self
    }
    
    @discardableResult
    func signInApp() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.signInWithTestAccount.rawValue)
        return self
    }
    
    @discardableResult
    func logout() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.logout.rawValue)
        return self
    }
    
    @discardableResult
    func populatePasswordsDB() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.populatePasswordsDB.rawValue)
        return self
    }
    
    @discardableResult
    func clearPasswordsDB() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.clearPasswordsDB.rawValue)
        return self
    }

    @discardableResult
    func showWebViewCount() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.showWebViewCount.rawValue)
        return self
    }
    
    @discardableResult
    func deletePrivateKeys() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.deletePrivateKeys.rawValue)
        return self
    }

    @discardableResult
    func deleteAllRemoteObjects() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.deleteAllRemoteObjects.rawValue)
        return self
    }
    
    @discardableResult
    func populateCreditCardsDB() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.populateCreditCardsDB.rawValue)
        return self
    }
    
    @discardableResult
    func clearCreditCardsDB() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.clearCreditCardsDB.rawValue)
        return self
    }
    
    @discardableResult
    func resetCollectAllert() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.resetCollectAlert.rawValue)
        return self
    }
    
    @discardableResult
    func setAPIEndpointsToStaging() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.setAPIEndpointsToStaging.rawValue)
        return self
    }
    
    @discardableResult
    func resetAPIEndpoints() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.resetAPIEndpoints.rawValue)
        return self
    }
    
    @discardableResult
    func signUpWithRandomTestAccount() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.signUpWithRandomTestAccount.rawValue)
        return self
    }
    
    @discardableResult
    func deleteRemoteAccount() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.deleteRemoteAccount.rawValue)
        return self
    }
    
    @discardableResult
    func showOnboarding() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.showOnboarding.rawValue)
        return self
    }
    
    @discardableResult
    func createNote() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.createNote.rawValue)
        return self
    }
    
    @discardableResult
    func create10Notes() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.create10Notes.rawValue)
        return self
    }
    
    @discardableResult
    func resizeSquare1000() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.resizeSquare1000.rawValue)
        return self
    }
    
    @discardableResult
    func createFakeDailySummary() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.createFakeDailySummary.rawValue)
        return self
    }

    @discardableResult
    func loadUITestPage1() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.loadUITestPage1.rawValue)
        return self
    }
    
    @discardableResult
    func loadUITestPage2() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.loadUITestPage2.rawValue)
        return self
    }
    
    @discardableResult
    func loadUITestPage3() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.loadUITestPage3.rawValue)
        return self
    }
    
    @discardableResult
    func loadUITestPage4() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.loadUITestPage4.rawValue)
        return self
    }

    @discardableResult
    func loadUITestPageAlerts() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.loadUITestPageAlerts.rawValue)
        return self
    }
    
    @discardableResult
    func loadUITestPageMedia() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.loadUITestPageMedia.rawValue)
        return self
    }
    
    @discardableResult
    func loadUITestSVG() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.loadUITestSVG.rawValue)
        return self
    }
    
    @discardableResult
    func loadUITestPagePassword() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.loadUITestPagePassword.rawValue)
        return self
    }
    
    @discardableResult
    func insertTextInCurrentNote() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.insertTextInCurrentNote.rawValue)
        return self
    }
    
    @discardableResult
    func setAutoUpdateToMock() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.setAutoUpdateToMock.rawValue)
        return self
    }
    
    @discardableResult
    func resizeWindowLandscape() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.resizeWindowLandscape.rawValue)
        return self
    }
    
    @discardableResult
    func resizeWindowPortrait() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.resizeWindowPortrait.rawValue)
        return self
    }

    @discardableResult
    func disableCreateJournalOnce() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.disableCreateJournalOnce.rawValue)
        return self
    }
    
    @discardableResult
    func enableCreateJournalOnce() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.enableCreateJournalOnce.rawValue)
        return self
    }
    
    @discardableResult
    func omniboxFillHistory() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.omniboxFillHistory.rawValue)
        return self
    }
    
    @discardableResult
    func omniboxDisableSearchInHistoryContent() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.omniboxDisableSearchInHistoryContent.rawValue)
        return self
    }
    
    @discardableResult
    func omniboxEnableSearchInHistoryContent() -> UITestsMenuBar {
        beeper.beep(identifier: UITestMenuAvailableCommands.omniboxEnableSearchInHistoryContent.rawValue)
        return self
    }
}
