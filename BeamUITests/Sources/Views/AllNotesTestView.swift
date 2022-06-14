//
//  AllNotesView.swift
//  BeamUITests
//
//  Created by Andrii on 23.07.2021.
//

import Foundation
import XCTest

class AllNotesTestView: BaseView {

    @discardableResult
    func waitForAllNotesViewToLoad() -> Bool {
        return app.tables.firstMatch.staticTexts.matching(identifier: AllNotesViewLocators.ColumnCells.noteTitleColumnCell.accessibilityIdentifier).firstMatch
            .waitForExistence(timeout: BaseTest.implicitWaitTimeout)
    }
    
    @discardableResult
    func waitForNoteTitlesToAppear() -> Bool {
        return staticText(AllNotesViewLocators.ColumnCells.noteTitleColumnCell.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout)
    }

    @discardableResult
    func deleteAllNotes() -> AllNotesTestView {
        triggerAllNotesMenuOptionAction(.deleteNotes)
        AlertTestView().confirmDeletion()
        return self
    }
    
    @discardableResult
    func deleteNoteByIndex(_ index: Int) -> AllNotesTestView {
        getNotesNamesElements()[index].hover()
        triggerSingleNoteMenuOptionAction(.deleteNotes)
        AlertTestView().confirmDeletion()
        return self
    }
    
    @discardableResult
    func triggerAllNotesMenuOptionAction(_ action: AllNotesViewLocators.MenuItems) -> AllNotesTestView {
        app.windows.children(matching: .image).matching(identifier: AllNotesViewLocators.Images.singleNoteEditor.accessibilityIdentifier).element(boundBy: 1).clickOnExistence()
        //Old way to click editor option
        //image(AllNotesViewLocators.Images.allNotesEditor.accessibilityIdentifier).clickOnExistence()
        menuItem(action.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    @discardableResult
    func triggerSingleNoteMenuOptionAction(_ action: AllNotesViewLocators.MenuItems) -> AllNotesTestView {
        app.windows.children(matching: .image).matching(identifier: AllNotesViewLocators.Images.singleNoteEditor.accessibilityIdentifier).element(boundBy: 0).clickOnExistence()
        //Old way to click editor option
        //image(AllNotesViewLocators.Images.singleNoteEditor.accessibilityIdentifier).clickOnExistence()
        menuItem(action.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    @discardableResult
    func openMenuForSingleNote(_ index: Int) -> AllNotesTestView {
        let singleNoteMenu = app.windows.children(matching: .image).matching(identifier: AllNotesViewLocators.Images.singleNoteEditor.accessibilityIdentifier).element(boundBy: 1)
        getNotesNamesElements()[index].hover()
        singleNoteMenu.hover()
        singleNoteMenu.clickOnExistence()
        return self
    }
    
    @discardableResult
    func selectActionInMenu(_ action: AllNotesViewLocators.MenuItems) -> AllNotesTestView {
        menuItem(action.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    func isElementAvailableInSingleNoteMenu(_ action: AllNotesViewLocators.MenuItems) -> Bool {
        return app.windows.menuItems[action.accessibilityIdentifier].exists
    }
    
    func getNotesNamesElements() -> [XCUIElement]{
        return app.windows.staticTexts.matching(identifier: AllNotesViewLocators.ColumnCells.noteTitleColumnCell.accessibilityIdentifier).allElementsBoundByIndex
    }
    
    func getNotesNamesElementQuery() -> XCUIElementQuery {
        return app.windows.staticTexts.matching(identifier: AllNotesViewLocators.ColumnCells.noteTitleColumnCell.accessibilityIdentifier)
    }
    
    func getNoteNameValueByIndex(_ index: Int) -> String {
        return self.getElementStringValue(element: getNotesNamesElements()[index])
    }
    
    func getNumberOfNotes() -> Int {
        getNotesNamesElements().count
    }
    
    @discardableResult
    func addNewNote(_ noteName: String) -> AllNotesTestView {
        XCTContext.runActivity(named: "Create a note named '\(noteName)' using + icon") {_ in
            tableTextField(AllNotesViewLocators.TextFields.newPrivateNote.accessibilityIdentifier).doubleClick()
            app.typeText(" " + noteName) //Workaround for CI that skips chars in the end
            tableImage(AllNotesViewLocators.Buttons.newNoteButton.accessibilityIdentifier).click()
            return self
        }
    }
    
    func isNoteNameAvailable(_ noteName: String) -> Bool {
        let notes = getNotesNamesElements()
        var i = notes.count
        repeat {
            let noteInList = self.getElementStringValue(element: notes[i - 1])
            if noteInList == noteName {
                return true
            }
            i -= 1
        } while i > 0
        return false
    }
    
    @discardableResult
    func openFirstNote() -> NoteTestView {
        app.windows.tables.staticTexts[AllNotesViewLocators.ColumnCells.noteTitleColumnCell.accessibilityIdentifier].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.015, dy: 0.9)).tap()
        return NoteTestView()
    }
    
    @discardableResult
    func openNoteByName(noteTitle: String) -> NoteTestView {
        var elementFound = false
        mainLoop: for element in self.getNotesNamesElements(){
            if getElementStringValue(element: element) == noteTitle {
                element.coordinate(withNormalizedOffset: CGVector(dx: 0.015, dy: 0.9)).tap()
                elementFound = true
                break mainLoop
            }
        }
        XCTAssertTrue(elementFound, "\(noteTitle) was not found in All Notes list")
        return NoteTestView()
    }
    
    @discardableResult
    func openJournal() -> JournalTestView {
        button(AllNotesViewLocators.Buttons.journalButton.accessibilityIdentifier).click()
        return JournalTestView()
    }
    
    func getPublishInstructionsLabel() -> XCUIElement {
        return label(AllNotesViewLocators.StaticTexts.publishInstruction.accessibilityIdentifier)
    }
    
    @discardableResult
    func openTableView(_ item: AllNotesViewLocators.ViewMenuItems) -> AllNotesTestTable {
        image(AllNotesViewLocators.Images.allNotesEditor.accessibilityIdentifier).tapInTheMiddle()
        menuItem(item.accessibilityIdentifier).clickOnExistence()
        return AllNotesTestTable()
    }
    
    func getViewCountValue() -> Int {
        let predicate = NSPredicate(format: "value BEGINSWITH 'All (' OR value BEGINSWITH 'Private (' OR value BEGINSWITH 'Published (' OR value BEGINSWITH 'On Profile ('")
        let viewCounterElement = app.windows.staticTexts.matching(predicate).firstMatch
        let viewStringValue = getElementStringValue(element: viewCounterElement).slice(from: "(", to: ")")!
        return Int(viewStringValue) ?? 0
    }
    
}
