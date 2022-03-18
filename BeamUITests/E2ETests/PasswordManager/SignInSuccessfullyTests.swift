//
//  SignInSuccessfullyTests.swift
//  BeamUITests
//
//  Created by Andrii on 23.09.2021.
//

import Foundation
import XCTest

class SignInSucessfullyTests: BaseTest {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        step("Given I start mock server"){
            launchApp()
            UITestsMenuBar().startMockHTTPServer()
        }
    }
    
    override func tearDown() {
        step("Given I stop mock server"){
            UITestsMenuBar().stopMockHTTPServer()
            super.tearDown()
        }
    }
    
    func SKIPtestSigninPage1() throws {
        try XCTSkipIf(true, "WIP")
        step("Given I "){}
    }
    
    
}
