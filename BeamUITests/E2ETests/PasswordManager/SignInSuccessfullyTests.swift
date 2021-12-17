//
//  SignInSuccessfullyTests.swift
//  BeamUITests
//
//  Created by Andrii on 23.09.2021.
//

import Foundation
import XCTest

class SignInSucessfullyTests: BaseTest {
    
    func testSignInGoogle() throws {
        try XCTSkipIf(true, "Skipped so far, until we can clean cookies")
        let journalView = launchApp()
        journalView.searchInOmniBox("gmail", true)
        testRailPrint("Then I sucessfully sign in Google")
        XCTAssertTrue(PasswordManagerHelper().signInGoogle(), "Failed to sign in")
    }
    
    func testSignInFacebook() throws {
        try XCTSkipIf(true, "Skipped so far, until we can clean cookies")
        let journalView = launchApp()
        journalView.searchInOmniBox("https://www.facebook.com/login/", true)
    }
    
    
}
