//
//  UITestsMenuBar.swift
//  BeamUITests
//
//  Created by Andrii on 26.07.2021.
//

import Foundation
import XCTest

class UITestsMenuBar: BaseMenuBar {
    
    let menuBarTitle = "UITests"
    
    private func openUITestsMenu() {
        menuBarItem(menuBarTitle).click()
    }
    
    @discardableResult
    func destroyDB() -> UITestsMenuBar {
        openUITestsMenu()
        menuItem(UITestMenuAvailableCommands.destroyDB.rawValue).clickOnExistence()
        return self
    }
    
    @discardableResult
    func startMockHTTPServer() -> UITestsMenuBar {
        openUITestsMenu()
        menuItem(UITestMenuGroup.mockHttpServer.rawValue).firstMatch.clickOnExistence()
        menuItem(UITestMenuAvailableCommands.startMockHttpServer.rawValue).clickOnExistence()
        return self
    }
    
    @discardableResult
    func stopMockHTTPServer() -> UITestsMenuBar {
        openUITestsMenu()
        menuItem(UITestMenuGroup.mockHttpServer.rawValue).firstMatch.clickOnExistence()
        menuItem(UITestMenuAvailableCommands.stopMockHttpServer.rawValue).clickOnExistence()
        return self
    }

    @discardableResult
    func deleteSFSymbolsFromDownloadFolder() -> UITestsMenuBar {
        openUITestsMenu()
        menuItem("Clean SF-Symbols-3.dmg from Downloads").click()
        return self
    }
    
    @discardableResult
    func signInApp() -> UITestsMenuBar {
        openUITestsMenu()
        menuItem("Sign in with Test Account").click()
        return self
    }
    
    @discardableResult
    func logout() -> UITestsMenuBar {
        openUITestsMenu()
        menuItem(UITestMenuAvailableCommands.logout.rawValue).clickOnExistence()
        return self
    }
    
    @discardableResult
    func populatePasswordsDB() -> UITestsMenuBar {
        openUITestsMenu()
        menuItem(UITestMenuAvailableCommands.populatePasswordsDB.rawValue).clickOnExistence()
        return self
    }

    @discardableResult
    func showWebViewCount() -> UITestsMenuBar {
        menuItem(UITestMenuAvailableCommands.showWebViewCount.rawValue).clickOnExistence()
        return self
    }
}
