//
//  TextEditorContextTestView.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 20.12.2021.
//

import Foundation
import XCTest

class TextEditorContextTestView: BaseView {
    
    override func textField(_ element: String) -> XCUIElement {
        return app.dialogs.textFields[element]
    }

    @discardableResult
    func selectFormatterOption(_ option: TextEditorContextViewLocators.Formatters) -> CardTestView {
        app.images[option.accessibilityIdentifier].clickOnExistence()
        return CardTestView()
    }

    @discardableResult
    func confirmBidiLinkCreation(cardName: String) -> CardTestView {
        let helper = OmniBoxUITestsHelper(app)
        app.otherElements.matching(helper.autocompleteCreateCardPredicate).firstMatch.clickOnExistence()
        return CardTestView()
    }

    func getLinkTitleTextFieldElement() -> XCUIElement {
        _ = app.dialogs.textFields[TextEditorContextViewLocators.TextFields.linkTitle.accessibilityIdentifier].waitForExistence(timeout: BaseTest.minimumWaitTimeout) //textField(TextEditorContextViewLocators.TextFields.linkTitle.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout)
        return app.dialogs.textFields[TextEditorContextViewLocators.TextFields.linkTitle.accessibilityIdentifier].firstMatch
        //textField(TextEditorContextViewLocators.TextFields.linkTitle.accessibilityIdentifier)
    }

    func getLinkURLTextFieldElement() -> XCUIElement {
        _ = app.dialogs.textFields[TextEditorContextViewLocators.TextFields.linkURL.accessibilityIdentifier].waitForExistence(timeout: BaseTest.minimumWaitTimeout)
        //_ = textField(TextEditorContextViewLocators.TextFields.linkURL.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout)
        //return textField(TextEditorContextViewLocators.TextFields.linkURL.accessibilityIdentifier)
        return app.dialogs.textFields[TextEditorContextViewLocators.TextFields.linkURL.accessibilityIdentifier].firstMatch
    }
    
    func doesStartedDailySummaryExist() -> Bool {
        return app.textViews.containing(.button, identifier: "Started").element.exists
    }
    
    func doesContinueOnDailySummaryExist() -> Bool {
        return app.textViews.containing(.button, identifier: "Continue").element.exists
    }
    
    func getCardNoteValueByIndex(_ index: Int) -> String {
        return self.getElementStringValue(element:  getCardNoteElementByIndex(index))
    }
    
    func getCardNoteElementByIndex(_ index: Int) -> XCUIElement {
        return self.getCardNotesForVisiblePart()[index]
    }
    
    func getCardNotesForVisiblePart() -> [XCUIElement] {
        return app.windows.textViews.matching(identifier: CardViewLocators.TextFields.textNode.accessibilityIdentifier).allElementsBoundByIndex
    }
    
    @discardableResult
    func openBiDiLink(_ linkName: String) -> CardTestView {
        app.windows.scrollViews.buttons[linkName].firstMatch.tapInTheMiddle()
        return CardTestView()
    }
    
    @discardableResult
    func openBiDiLink(_ index: Int) -> CardTestView {
        app.buttons.matching(identifier: "internalLink").element(boundBy: index).tapInTheMiddle()
        return CardTestView()
    }
    
    @discardableResult
    func typeInCardNoteByIndex(noteIndex: Int, text: String, needsActivation: Bool = false) -> TextEditorContextTestView {
        if needsActivation {
            getCardNotesForVisiblePart()[noteIndex].tapInTheMiddle()
        }
        app.typeText(text)
        return self
    }
}
