//
//  SignInTests.swift
//  BeamUITests
//
//  Created by Andrii on 07/10/2021.
//

import Foundation
import XCTest

class SignInTests: BaseTest {
    
    func testSignInSuccessfully() throws {
        try XCTSkipIf(true, "Blocked by https://linear.app/beamapp/issue/BE-2159/perform-uitest-locally-trigger-the-vinyl-fatalerror")
        self.launchApp()
        UITestsMenuBar().logout()
        self.restartApp()
        ShortcutsHelper().shortcutActionInvoke(action: .openPreferences)
        GeneralPreferenceTestView().navigateTo(menu: .account)
        
        let accountView = AccountTestView().signIn()
        self.restartApp()
        testRailPrint("Then ")
        
    }
    
}
