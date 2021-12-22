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
    func selectEditorOption(_ option: TextEditorContextViewLocators.Images) -> CardTestView {
        app.images[option.accessibilityIdentifier].clickOnExistence()
        return CardTestView()
    }
    
    @discardableResult
    func confirmBidiLinkCreation(cardName: String) -> CardTestView {
        app.otherElements["autocompleteResult-selected-\(cardName)-createCard"].clickOnExistence()
        return CardTestView()
    }
    
    func getLinkTitleTextFieldElement() -> XCUIElement {
        _ = app.dialogs.textFields[TextEditorContextViewLocators.TextFields.linkTitle.accessibilityIdentifier].waitForExistence(timeout: minimumWaitTimeout) //textField(TextEditorContextViewLocators.TextFields.linkTitle.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout)
        return app.dialogs.textFields[TextEditorContextViewLocators.TextFields.linkTitle.accessibilityIdentifier].firstMatch
        //textField(TextEditorContextViewLocators.TextFields.linkTitle.accessibilityIdentifier)
    }
    
    func getLinkURLTextFieldElement() -> XCUIElement {
        _ = app.dialogs.textFields[TextEditorContextViewLocators.TextFields.linkURL.accessibilityIdentifier].waitForExistence(timeout: minimumWaitTimeout)
        //_ = textField(TextEditorContextViewLocators.TextFields.linkURL.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout)
        //return textField(TextEditorContextViewLocators.TextFields.linkURL.accessibilityIdentifier)
        return app.dialogs.textFields[TextEditorContextViewLocators.TextFields.linkURL.accessibilityIdentifier].firstMatch
    }
}
