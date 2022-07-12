//
//  ContextViewTests.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 20.12.2021.
//

import Foundation
import XCTest

class TextEditorContextViewTests: BaseTest {
    
    let textEditorContext = TextEditorContextTestView()
    let allNotesView = AllNotesTestView()
    var noteView: NoteTestView!
    
    func testCreateNoteViaContextView() {
        let textToType = "text before a new note"
        let numberOfCharsToSelect = 8
        let index = textToType.index(textToType.endIndex, offsetBy: -numberOfCharsToSelect)
        let noteName = String(textToType[index...])
        
        step("Given open today's note"){
            noteView = launchApp()
                .openAllNotesMenu()
                .openFirstNote()
        }
        
        step("When I create a bidi link out of typed text: \(textToType)"){
            noteView.typeInNoteNodeByIndex(noteIndex: 0, text: textToType)
            shortcutHelper.shortcutActionInvokeRepeatedly(action: .selectOnLeft, numberOfTimes: numberOfCharsToSelect)
            textEditorContext.selectFormatterOption(.bidi)
            textEditorContext.confirmBidiLinkCreation(noteName: noteName)
        }
        
        step("Then the note text is remained: \(textToType)"){
            XCTAssertEqual(textToType + " ", noteView.getNoteNodeValueByIndex(0))
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            XCTAssertTrue(allNotesView.waitForNoteTitlesToAppear(), "Note titles didn't load during the timeout")
            allNotesView.openNoteByName(noteTitle: noteName)
        }
        
        step("Then new note is created"){
            _ = noteView.waitForNoteToOpen(noteTitle: noteName)
            XCTAssertEqual(noteName, noteView.getNoteTitle())
            XCTAssertEqual(1, noteView.getLinksContentNumber())
            XCTAssertEqual(textToType + " ", noteView.getLinkContentByIndex(0))
        }
       
    }
    
    func testBidiLinkViaContextView() {
        let notePrefix = "prefix"
        let noteName = "BiDi note"
        let notePostix = "postfix"
        let noteName1 = "BiDied note"
        let composedText = notePrefix + noteName + notePostix
        
        step("Given I create \(noteName)"){
            let journalView = launchApp()
            noteView = journalView.createNoteViaOmniboxSearch(noteName)//https://linear.app/beamapp/issue/BE-4443/allow-typing-in-texteditor-of-the-note-created-via-uitest-menu
        }
        
        step("When I type in note: \(composedText)"){
            noteView.createBiDiLink(noteName1)
                .openBiDiLink(0)
                .typeInNoteNodeByIndex(noteIndex: 0, text: composedText)
                .typeKeyboardKey(.leftArrow, notePostix.count)
            shortcutHelper.shortcutActionInvokeRepeatedly(action: .selectOnLeft, numberOfTimes: noteName.count)
        }
        
        step("When I create a BiDi link for: \(noteName)"){
            textEditorContext.selectFormatterOption(.bidi)
            XCTAssertFalse(textEditorContext.getLinkTitleTextFieldElement().waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step("Then BiDi link appears for: \(noteName)"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName)
            XCTAssertEqual(noteName, noteView.getNoteTitle())
            XCTAssertEqual(1, noteView.getLinksContentNumber())
            XCTAssertEqual(composedText, noteView.getLinkContentByIndex(0))
        }
        
    }
    
    func SKIPtestCreateHyperlinkViaContextView() throws {
        try XCTSkipIf(true, "Dialog is not being locatable on CI. To be ran locally so far")
        let linkTitle = "the link"
        let linkURL = "www.google.com"
        let expectedTabURL = "google.com/"
        
        step("Given open today's note"){
            noteView = launchApp()
                .openAllNotesMenu()
                .openFirstNote()
        }

        //create an empty link
        //TBD once https://linear.app/beamapp/issue/BE-2791/it-is-possible-to-create-an-empty-link-in-card-note-via-text-editor is fixed
        
        step("When I create a hyperlink out of typed text: \(linkTitle)"){
            noteView.typeInNoteNodeByIndex(noteIndex: 0, text: linkTitle)
            shortcutHelper.shortcutActionInvokeRepeatedly(action: .selectOnLeft, numberOfTimes: linkTitle.count)
            textEditorContext.selectFormatterOption(.link)
        }
        
        step("Then I see hyperlink creation pop-up appeared"){
            XCTAssertEqual(textEditorContext.getLinkTitleTextFieldElement().getStringValue(), linkTitle)
            XCTAssertEqual(textEditorContext.getLinkURLTextFieldElement().getStringValue(), emptyString)
        }
      
        step("When I a hyperlink to: \(linkURL)"){
            textEditorContext.getLinkURLTextFieldElement().typeText(linkURL)
            textEditorContext.typeKeyboardKey(.enter)
        }
       
        step("Then the pop-up is closed and the note value is still: \(linkURL)"){
            waitForDoesntExist(textEditorContext.getLinkTitleTextFieldElement())
            XCTAssertEqual(noteView.getNoteNodeValueByIndex(0), linkTitle)
        }

        step("When I click on created hyperlink"){
            noteView.getNoteNodeElementByIndex(0).coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).tap()
        }
        
        step("Then the webview is opened and \(linkURL) is searched"){
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 1)
            XCTAssertEqual(webView.getTabUrlAtIndex(index: 0), expectedTabURL)
        }
        
    }
    
    func testFormatTextViaContextView() {
        let text = "THE_text 2 TE$t"
        step("Given open today's note"){
            noteView = launchApp()
                .openAllNotesMenu()
                .openFirstNote()
        }

        step("When I type: \(text)"){
            noteView.typeInNoteNodeByIndex(noteIndex: 0, text: text)
            shortcutHelper.shortcutActionInvoke(action: .selectAll)
        }
        
        step("Then I select bold, italic, h1, h2"){
            textEditorContext.selectFormatterOption(.bold)
            textEditorContext.selectFormatterOption(.italic)
            textEditorContext.selectFormatterOption(.h1)
            textEditorContext.selectFormatterOption(.h2)
        }
       
        step("Then text remains the same"){ //there is no other ways so far to assert it is applied correctly
            //Could be done by using screenshots of the element in future
            XCTAssertEqual(noteView.getNoteNodeValueByIndex(0), text)
        }

        step("Then I can dismiss text editor context menu by ESC"){
            shortcutHelper.shortcutActionInvoke(action: .selectAll)
            noteView.typeKeyboardKey(.escape)
            waitForDoesntExist(textEditorContext.image(TextEditorContextViewLocators.Formatters.h2.accessibilityIdentifier))
            self.assertFormatterOptionsDontExist()
        }
        
        step("Then I can dismiss text editor context menu by clicking outside"){
            shortcutHelper.shortcutActionInvoke(action: .selectAll)
            noteView.getNoteNodeElementByIndex(0).tapInTheMiddle()
            waitForDoesntExist(textEditorContext.image(TextEditorContextViewLocators.Formatters.h2.accessibilityIdentifier))
            self.assertFormatterOptionsDontExist()
        }
       
    }
    
    private func assertFormatterOptionsDontExist() {
        for item in TextEditorContextViewLocators.Formatters.allCases {
            let identifier = item.accessibilityIdentifier
            let element = textEditorContext.image(identifier).firstMatch
                XCTAssertFalse(element.exists && element.isEnabled && element.isHittable, "element \(identifier) exists but shouldn't")
        }
    }
    
}
