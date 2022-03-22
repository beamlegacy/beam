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
}
