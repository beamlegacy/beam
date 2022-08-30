//
//  AllNotesExportImportTests.swift
//  BeamUITests
//
//  Created by Andrii on 30/08/2022.
//

import Foundation
import XCTest

class AllNotesExportImportTests: BaseTest {
    
    let allNotesView = AllNotesTestView()
    
    override func setUp() {
        step("GIVEN I open All Notes") {
            launchApp()
            uiMenu.createNote()
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
        }
    }
    
    private func assertAndCancelFinderWindow(_ isImport: Bool = true) {
        step("THEN Finder window is opened") {
            let finderWindow = XCUIApplication().dialogs.firstMatch
            XCTAssertTrue(finderWindow.waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            if (isImport) {
                XCTAssertTrue(finderWindow.buttons["Open"].exists)
            } else {
                XCTAssertTrue(finderWindow.buttons["Export"].exists || finderWindow.buttons["Save"].exists)
            }
            finderWindow.buttons["Cancel"].clickOnExistence()
            XCTAssertTrue(waitForDoesntExist(finderWindow))
        }
    }
    
    func testImportNotesClickOpensFinder() {
        testrailId("C721")
        step("WHEN I click Export Beam note option") {
            allNotesView.allNotesImportExportCallFor(firstMenu: .importNotes, secondMenu: .importJSON)
        }
        assertAndCancelFinderWindow()

        testrailId("C719")
        step("WHEN I click Export Roam option") {
            allNotesView.allNotesImportExportCallFor(firstMenu: .importNotes, secondMenu: .importRoam)
        }
        assertAndCancelFinderWindow()
        
        testrailId("C720")
        step("WHEN I click Export Backup option") {
            allNotesView.allNotesImportExportCallFor(firstMenu: .importNotes, secondMenu: .importBackup)
        }
        assertAndCancelFinderWindow()
        
        testrailId("C1179")
        step("WHEN I click Export Markdown option") {
            allNotesView.allNotesImportExportCallFor(firstMenu: .importNotes, secondMenu: .importMarkdown)
        }
        assertAndCancelFinderWindow()
    }
    
    func testExportNotesClickOpensFinder() {
        testrailId("C717")
        step("WHEN I click Export Beam backup option") {
            allNotesView.allNotesImportExportCallFor(firstMenu: .exportNotes, secondMenu: .exportBackup)
        }
        assertAndCancelFinderWindow(false)
        
        testrailId("C718")
        step("WHEN I click Export Markdown note option") {
            allNotesView.allNotesImportExportCallFor(firstMenu: .exportNotes, secondMenu: .exportMarkdown)
        }
        assertAndCancelFinderWindow(false)
        
        testrailId("C715")
        step("WHEN I click Export Beam note option for a single note") {
            allNotesView
                .openMenuForSingleNote(0)
                .selectActionInMenu(.exportSingleNote)
        }
        assertAndCancelFinderWindow(false)
        
        step("WHEN I click Export Beam note option a single note") {
            allNotesView
                .openMenuForSingleNote(0)
                .selectActionInMenu(.exportMarkdown)
        }
        assertAndCancelFinderWindow(false)
        
        step("WHEN I click Export Beam note option for multiple notes") {
            allNotesView
                .selectAllRows()
                .openMenuForSingleNote(0)
                .selectActionInMenu(.exportSingleNote)
        }
        assertAndCancelFinderWindow()
        
        step("WHEN I click Export Beam note option for multiple notes") {
            allNotesView
                .openMenuForSingleNote(0)
                .selectActionInMenu(.exportMarkdown)
        }
        assertAndCancelFinderWindow(false)
    }
    
}
