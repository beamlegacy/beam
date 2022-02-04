//
//  PasswordPreferencesTests.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 03.02.2022.
//

import Foundation
import XCTest

class PasswordPreferencesTests: BaseTest {
    
    let shortcutsHelper = ShortcutsHelper()
    
    func testAddPasswordItem() throws {
        try XCTSkipIf(true, "WIP")
        launchApp()
        testRailPrint("GIVEN I open prefernces and click add button")
        shortcutsHelper.shortcutActionInvoke(action: .openPreferences)
        
        
        testRailPrint("THEN nothing is added on clicking Cancel button and the pop-up is closed")
        
        
        testRailPrint("THEN nothing happens on clicking Add password button")

        
        testRailPrint("THEN nothing happens on clicking Add password button with hostname populated only")

        
        testRailPrint("THEN nothing happens on clicking Add password button with hostname and username populated only")
        
        
        testRailPrint("THEN I see an error on clicking Add password button with incorrect hostname and correct username and password populated")
        
        
        testRailPrint("THEN password item is successfully added when correct hostname format is typed")
        
    }
    
    func testRemovePasswordItem() throws {
        try XCTSkipIf(true, "WIP")
    }
    
    func testViewPasswordItemDetails() throws {
        try XCTSkipIf(true, "WIP")
    }
    
    func testSearchForPassword() throws {
        try XCTSkipIf(true, "WIP")
    }
    
    func testSortPasswords() throws {
        try XCTSkipIf(true, "WIP")
    }
    
    func testAutofillUsernameAndPasswords() throws {
        try XCTSkipIf(true, "WIP")
    }
    
    func testImportPasswords() throws {
        try XCTSkipIf(true, "WIP")
    }
    
    func testExportPasswords() throws {
        try XCTSkipIf(true, "WIP")
    }
    
}
