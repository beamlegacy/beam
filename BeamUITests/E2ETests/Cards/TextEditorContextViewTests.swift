//
//  ContextViewTests.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 20.12.2021.
//

import Foundation
import XCTest

class TextEditorContextViewTests: BaseTest {
    
    let shortcutsHelper = ShortcutsHelper()
    let textEditorContext = TextEditorContextTestView()
    let webView = WebTestView()
    let allCardsView = AllCardsTestView()
    
    func testCreateCardViaContextView() {
        let textToType = "text before a new note"
        let numberOfCharsToSelect = 8
        
        testRailPrint("Given open today's note")
        let cardView = launchApp()
            .openAllCardsMenu()
            .openFirstCard()
        
        testRailPrint("When I create a bidi link out of typed text: \(textToType)")
        cardView.typeInCardNoteByIndex(noteIndex: 0, text: textToType)
        shortcutsHelper.shortcutActionInvokeRepeatedly(action: .selectOnLeft, numberOfTimes: numberOfCharsToSelect)
        textEditorContext.selectFormatterOption(.bidi)
        textEditorContext.confirmBidiLinkCreation(cardName: "new note")
        
        testRailPrint("Then the note text is remained: \(textToType)")
        XCTAssertEqual(textToType + " ", cardView.getCardNoteValueByIndex(0))
        shortcutsHelper.shortcutActionInvoke(action: .showAllCards)
        allCardsView.waitForAllCardsViewToLoad()
        //Substring to be used
        allCardsView.openCardByName(cardTitle: "new note")
        
        testRailPrint("Then new note is created")
        cardView.waitForCardViewToLoad()
        XCTAssertEqual("new note", cardView.getCardTitle())
        XCTAssertEqual(1, cardView.getLinksContentNumber())
        XCTAssertEqual(textToType + " ", cardView.getLinkContentByIndex(0))
    }
    
    func testBidiLinkViaContextView() {
        let notePrefix = "prefix"
        let cardName = "BiDi note"
        let notePostix = "postfix"
        let cardName1 = "BiDied note"
        let composedText = notePrefix + cardName + notePostix
        
        testRailPrint("Given I create \(cardName)")
        let journalView = launchApp()
        let cardView = journalView.createCardViaOmniboxSearch(cardName)
        
        testRailPrint("When I type in note: \(composedText)")
        cardView.createBiDiLink(cardName1)
            .openBiDiLink(0)
            .typeInCardNoteByIndex(noteIndex: 0, text: composedText)
            .typeKeyboardKey(.leftArrow, notePostix.count)
        shortcutsHelper.shortcutActionInvokeRepeatedly(action: .selectOnLeft, numberOfTimes: cardName.count)
        
        testRailPrint("When I create a BiDi link for: \(cardName)")
        textEditorContext.selectFormatterOption(.bidi)
        XCTAssertFalse(textEditorContext.getLinkTitleTextFieldElement().waitForExistence(timeout: minimumWaitTimeout))
        
        testRailPrint("Then BiDi link appears for: \(cardName)")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName)
        XCTAssertEqual(cardName, cardView.getCardTitle())
        XCTAssertEqual(1, cardView.getLinksContentNumber())
        XCTAssertEqual(composedText, cardView.getLinkContentByIndex(0))
    }
    
    func testCreateHyperlinkViaContextView() throws {
        try XCTSkipIf(true, "Dialog is not being locatable on CI. To be ran locally so far")
        let linkTitle = "the link"
        let linkURL = "www.google.com"
        let expectedTabURL = "google.com/"
        
        testRailPrint("Given open today's note")
        let cardView = launchApp()
            .openAllCardsMenu()
            .openFirstCard()
        
        //create an empty link
        //TBD once https://linear.app/beamapp/issue/BE-2791/it-is-possible-to-create-an-empty-link-in-card-note-via-text-editor is fixed
        
        testRailPrint("When I create a hyperlink out of typed text: \(linkTitle)")
        cardView.typeInCardNoteByIndex(noteIndex: 0, text: linkTitle)
        shortcutsHelper.shortcutActionInvokeRepeatedly(action: .selectOnLeft, numberOfTimes: linkTitle.count)
        textEditorContext.selectFormatterOption(.link)
        
        testRailPrint("Then I see hyperlink creation pop-up appeared")
        XCTAssertEqual(cardView.getElementStringValue(element:  textEditorContext.getLinkTitleTextFieldElement()), linkTitle)
        XCTAssertEqual(cardView.getElementStringValue(element:  textEditorContext.getLinkURLTextFieldElement()), emptyString)
        
        testRailPrint("When I a hyperlink to: \(linkURL)")
        textEditorContext.getLinkURLTextFieldElement().typeText(linkURL)
        textEditorContext.typeKeyboardKey(.enter)
        
        testRailPrint("Then the pop-up is closed and the note value is still: \(linkURL)")
        WaitHelper().waitForDoesntExist(textEditorContext.getLinkTitleTextFieldElement())
        XCTAssertEqual(cardView.getCardNoteValueByIndex(0), linkTitle)
        
        testRailPrint("When I click on created hyperlink")
        cardView.getCardNoteElementByIndex(0).coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).tap()
        
        testRailPrint("Then the webview is opened and \(linkURL) is searched")
        XCTAssertEqual(webView.getNumberOfTabs(), 1)
        XCTAssertEqual(webView.getTabUrlAtIndex(index: 0), expectedTabURL)
    }
    
    func testFormatTextViaContextView() {
        let text = "THE_text 2 TE$t"
        testRailPrint("Given open today's note")
        let cardView = launchApp()
            .openAllCardsMenu()
            .openFirstCard()
        
        testRailPrint("When I type: \(text)")
        cardView.typeInCardNoteByIndex(noteIndex: 0, text: text)
        shortcutsHelper.shortcutActionInvoke(action: .selectAll)
        
        testRailPrint("Then I select bold, italic, h1, h2")
        textEditorContext.selectFormatterOption(.bold)
        textEditorContext.selectFormatterOption(.italic)
        textEditorContext.selectFormatterOption(.h1)
        textEditorContext.selectFormatterOption(.h2)

        testRailPrint("Then text remains the same") //there is no other ways so far to assert it is applied correctly
        //Could be done by using screenshots of the element in future
        XCTAssertEqual(cardView.getCardNoteValueByIndex(0), text)
        
        testRailPrint("Then I can dismiss text editor context menu by ESC")
        shortcutsHelper.shortcutActionInvoke(action: .selectAll)
        cardView.typeKeyboardKey(.escape)
        WaitHelper().waitForDoesntExist(textEditorContext.image(TextEditorContextViewLocators.Formatters.h2.accessibilityIdentifier))
        self.assertFormatterOptionsDontExist()
        
        testRailPrint("Then I can dismiss text editor context menu by clicking outside")
        shortcutsHelper.shortcutActionInvoke(action: .selectAll)
        cardView.getCardNoteElementByIndex(0).tapInTheMiddle()
        WaitHelper().waitForDoesntExist(textEditorContext.image(TextEditorContextViewLocators.Formatters.h2.accessibilityIdentifier))
        self.assertFormatterOptionsDontExist()
    }
    
    private func assertFormatterOptionsDontExist() {
        for item in TextEditorContextViewLocators.Formatters.allCases {
            let identifier = item.accessibilityIdentifier
            let element = textEditorContext.image(identifier).firstMatch
                XCTAssertFalse(element.exists && element.isEnabled && element.isHittable, "element \(identifier) exists but shouldn't")
        }
    }
    
}
