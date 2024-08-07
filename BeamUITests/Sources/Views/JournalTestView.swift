//
//  JournalView.swift
//  BeamUITests
//
//  Created by Andrii on 26.07.2021.
//

import Foundation
import XCTest

class JournalTestView: TextEditorContextTestView {
    
    func getScrollViewElement() -> XCUIElement {
        return scrollView(JournalViewLocators.ScrollViews.journalScrollView.accessibilityIdentifier)
    }
    
    func getHelpButton() -> XCUIElement {
        button(ToolbarLocators.Buttons.helpButton.accessibilityIdentifier)
    }
    
    @discardableResult
    func openAllNotesMenu() -> AllNotesTestView {
        let allNotesMenuButton = button(ToolbarLocators.Buttons.noteSwitcherAllNotes.accessibilityIdentifier)
        waitFor(PredicateFormat.isHittable.rawValue, allNotesMenuButton)
        allNotesMenuButton.clickOnExistence()
        return AllNotesTestView()
    }
    
    @discardableResult
    func openRecentNoteByName(_ noteName: String) -> NoteTestView {
        let button = app.buttons.matching(identifier: ToolbarLocators.Buttons.noteSwitcher.accessibilityIdentifier)
            .matching(NSPredicate(format: "value = '\(noteName)'")).firstMatch
        waitFor(PredicateFormat.isHittable.rawValue, button)
        button.clickOnExistence()
        return NoteTestView()
    }
    
    @discardableResult
    func openHelpMenu() -> HelpTestView {
        getHelpButton().clickOnHittable()
        return HelpTestView()
    }
    
    @discardableResult
    func createNoteViaOmniboxSearch(_ noteNameToBeCreated: String) -> NoteTestView {
        shortcutHelper.shortcutActionInvoke(action: .newTab)
        searchInOmniBox(noteNameToBeCreated, false)
        app.typeKey(.enter, modifierFlags: .option)
        waitForDoesntExist(searchField(ToolbarLocators.SearchFields.omniSearchField.accessibilityIdentifier))
        NoteTestView().waitForNoteViewToLoad()
        return NoteTestView()
    }
    
    @discardableResult
    func scroll(_ numberOfScrolls: Int) -> JournalTestView {
        for _ in 0...numberOfScrolls {
            getScrollViewElement().scroll(byDeltaX: 0, deltaY: -1000)
        }
        return self
    }
    
    @discardableResult
    func getNoteByIndex(_ i: Int) -> XCUIElement {
        let index = i - 1
        return getScrollViewElement().children(matching: .textView).matching(identifier: NoteViewLocators.TextFields.textNode.accessibilityIdentifier).element(boundBy: index)
    }
    
    @discardableResult
    func waitForJournalViewToLoad() -> JournalTestView {
        _ = getScrollViewElement().waitForExistence(timeout: BaseTest.implicitWaitTimeout)
        return self
    }
    
    func isJournalOpened() -> Bool {
        return getScrollViewElement().exists
    }
    
    func clickUpdateNow() -> UpdateTestView {
        self.staticText(JournalViewLocators.StaticTexts.updateNowButton.accessibilityIdentifier).clickOnExistence()
        return UpdateTestView()
    }
    
    func getImageNodes() -> [XCUIElement] {
        return app.windows.scrollViews[JournalViewLocators.ScrollViews.journalScrollView.accessibilityIdentifier].textViews.matching(identifier: NoteViewLocators.TextFields.imageNode.accessibilityIdentifier).allElementsBoundByIndex
    }
    
    func getImageNodesCount() -> Int {
        return getImageNodes().count
    }
    
    func getTextNodeMatching(value: String) -> XCUIElement {
        let matchPredicate = NSPredicate(format: "value = %@", value)
        return getScrollViewElement().children(matching: .textView).matching(identifier: NoteViewLocators.TextFields.textNode.accessibilityIdentifier).element(matching: matchPredicate)
    }
    
    func isTextNodeDisplayed(matchingValue: String) -> Bool {
        return getTextNodeMatching(value: matchingValue).waitForExistence(timeout: BaseTest.implicitWaitTimeout)
    }
}
