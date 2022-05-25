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
}
