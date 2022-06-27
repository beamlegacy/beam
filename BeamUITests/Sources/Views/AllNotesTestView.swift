//
//  AllNotesView.swift
//  BeamUITests
//
//  Created by Andrii on 23.07.2021.
//

import Foundation
import XCTest

class AllNotesTestView: BaseView {

    var sortingCounterValues: SortingCounterValues!
    
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
    func waitForNotesNumberEqualTo(_ number: Int) -> Bool {
        waitForCountValueEqual(timeout: implicitWaitTimeout, expectedNumber: number, elementQuery: app.windows.staticTexts.matching(identifier: AllNotesViewLocators.ColumnCells.noteTitleColumnCell.accessibilityIdentifier))
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
        //Sometimes the curosr stays on a note in a table making '...' editor appears confusing XCUITests so it click a wrong element
        button(AllNotesViewLocators.SortButtons.title.accessibilityIdentifier).hover()
        waitForAllNotesViewToLoad()
        if BaseTest().isBigSurOS() {
            image(AllNotesViewLocators.Images.singleNoteEditor.accessibilityIdentifier).clickOnExistence()
        } else {
            app.windows.children(matching: .image).matching(identifier: AllNotesViewLocators.Images.singleNoteEditor.accessibilityIdentifier).element(boundBy: 1).clickOnExistence()
        }
        menuItem(action.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    @discardableResult
    func triggerSingleNoteMenuOptionAction(_ action: AllNotesViewLocators.MenuItems) -> AllNotesTestView {
        app.windows.children(matching: .image).matching(identifier: AllNotesViewLocators.Images.singleNoteEditor.accessibilityIdentifier).element(boundBy: 0).clickOnExistence()
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
        return getNotesNamesElements()[index].getStringValue()
    }
    
    func getNumberOfNotes() -> Int {
        getNotesNamesElements().count
    }
    
    @discardableResult
    func addNewPrivateNote(_ noteName: String) -> AllNotesTestView {
        XCTContext.runActivity(named: "Create a note named '\(noteName)' using + icon") {_ in
            tableTextField(AllNotesViewLocators.TextFields.newPrivateNote.accessibilityIdentifier).doubleClick()
            app.typeText(" " + noteName) //Workaround for CI that skips chars in the end
            tableImage(AllNotesViewLocators.Buttons.newNoteButton.accessibilityIdentifier).clickOnExistence()
            return self
        }
    }
    
    @discardableResult
    func typeCardNameAndClickAddFor(sortType: AllNotesViewLocators.TextFields, noteName: String) -> AllNotesTestView {
        _ = tableTextField(sortType.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout)
        tableTextField(sortType.accessibilityIdentifier).clickAndType(" " + noteName)
        tableImage(AllNotesViewLocators.Buttons.newNoteButton.accessibilityIdentifier).click()
        return self
    }
    
    func isNoteNameAvailable(_ noteName: String) -> Bool {
        let notes = getNotesNamesElements()
        var i = notes.count
        repeat {
            let noteInList = notes[i - 1].getStringValue()
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
            if element.getStringValue() == noteTitle {
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
        button(AllNotesViewLocators.Buttons.journalButton.accessibilityIdentifier).clickOnExistence()
        return JournalTestView()
    }
    
    func getPublishInstructionsLabel() -> XCUIElement {
        return label(AllNotesViewLocators.StaticTexts.publishInstruction.accessibilityIdentifier)
    }
    
    @discardableResult
    func openTableView(_ item: AllNotesViewLocators.ViewMenuItems) -> AllNotesTestTable {
        if !menuItem(item.accessibilityIdentifier).exists {
            self.clickSortingDropDownExpandTriangle()
        }
        menuItem(item.accessibilityIdentifier).clickOnExistence()
        return AllNotesTestTable()
    }
    
    @discardableResult
    func clickSortingDropDownExpandTriangle() -> AllNotesTestView {
        image(AllNotesViewLocators.Images.allNotesEditor.accessibilityIdentifier).tapInTheMiddle()
        return self
    }
    
    func getViewCountValue() -> Int {
        let predicate = NSPredicate(format: "value BEGINSWITH 'All (' OR value BEGINSWITH 'Private (' OR value BEGINSWITH 'Published (' OR value BEGINSWITH 'On Profile ('")
        let viewCounterElement = app.windows.staticTexts.matching(predicate).firstMatch
        let viewStringValue = viewCounterElement.getStringValue().slice(from: "(", to: ")")!
        return Int(viewStringValue) ?? 0
    }
    
    @discardableResult
    func sortTableBy(_ column: AllNotesViewLocators.SortButtons) -> AllNotesTestView {
        app.windows.buttons[column.accessibilityIdentifier].firstMatch.tapInTheMiddle()
        return self
    }
    
    func getAllSortingCounterValues() -> AllNotesTestView {
        self.clickSortingDropDownExpandTriangle()
        sortingCounterValues = SortingCounterValues(
            all: getSortingCounterValue(.allNotes),
            privat: getSortingCounterValue(.privateNotes),
            published: getSortingCounterValue(.publishedNotes),
            publishedProfile: getSortingCounterValue(.profileNotes))
        return self
    }
    
    func getURLiconElementFor(rowIndex: Int) -> XCUIElement {
        return button(AllNotesViewLocators.Buttons.urlIcon.accessibilityIdentifier + String(rowIndex))
    }
    
    func getSortingCounterValue(_ item: AllNotesViewLocators.ViewMenuItems) -> Int {
        let value = menuItem(item.accessibilityIdentifier).title
        let integerValue = Int(value.slice(from: "(", to: ")") ?? "-1")!
        return integerValue
    }
    
    func waitForPublishingProcessToStartAndFinishFor(_ noteName: String) -> Bool {
        let publishStatusElement = textField("Publishing '\(noteName)'...")
        _ = publishStatusElement.waitForExistence(timeout: implicitWaitTimeout)
        return waitForDoesntExist(publishStatusElement)
    }
    
    class SortingCounterValues: BaseRow {
        var all: Int!
        var privat: Int!
        var published: Int!
        var publishedProfile: Int!
        
        init(all: Int, privat: Int, published: Int, publishedProfile: Int) {
            self.all = all
            self.privat = privat
            self.published = published
            self.publishedProfile = publishedProfile
        }
    }
    
}
