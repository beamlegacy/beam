//
//  IncognitoModeTests.swift
//  BeamUITests
//
//  Created by Andrii on 12/04/2022.
//

import Foundation
import XCTest

class IncognitoModeTests: BaseTest {
    
    func testIcognitoModeEnabling() {
        testrailId("C904, C500")
        let journalView = JournalTestView()
        
        step ("Given I enable an incognito mode"){
            shortcutHelper.shortcutActionInvoke(action: .newIncognitoWindow)
        }
        
        step ("Then I see incognito mode is enabled on UI"){
            XCTAssertTrue(journalView.image(OmniboxViewLocators.Images.incognitoIcon.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(journalView.staticText(OmniboxViewLocators.StaticTexts.incognitoHeader.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertEqual(journalView.app.windows.count, 2)
        }
        
        //To be added history control functionality in UI menu to assert if the browsing history is captured
        
    }
    
}
