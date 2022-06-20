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
    func selectFormatterOption(_ option: TextEditorContextViewLocators.Formatters) -> NoteTestView {
        app.images[option.accessibilityIdentifier].clickOnExistence()
        return NoteTestView()
    }

    @discardableResult
    func confirmBidiLinkCreation(noteName: String) -> NoteTestView {
        let helper = OmniBoxUITestsHelper(app)
        app.otherElements.matching(helper.autocompleteCreateNotePredicate).firstMatch.clickOnExistence()
        return NoteTestView()
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
    
    func getNoteNodeValueByIndex(_ index: Int) -> String {
        return self.getElementStringValue(element:  getNoteNodeElementByIndex(index))
    }
    
    func getNoteNodeElementByIndex(_ index: Int) -> XCUIElement {
        return self.getNoteNodesForVisiblePart()[index]
    }
    
    func getNoteNodesForVisiblePart() -> [XCUIElement] {
        return app.windows.textViews.matching(identifier: NoteViewLocators.TextFields.textNode.accessibilityIdentifier).allElementsBoundByIndex
    }
    
    @discardableResult
    func openBiDiLink(_ linkName: String) -> NoteTestView {
        let link = app.windows.scrollViews.buttons[linkName].firstMatch
        link.hoverInTheMiddle()
        link.tapInTheMiddle()
        return NoteTestView()
    }
    
    @discardableResult
    func openBiDiLink(_ index: Int) -> NoteTestView {
        app.buttons.matching(identifier: "internalLink").element(boundBy: index).tapInTheMiddle()
        return NoteTestView()
    }
    
    @discardableResult
    func typeInNoteNodeByIndex(noteIndex: Int, text: String, needsActivation: Bool = false) -> TextEditorContextTestView {
        if needsActivation {
            getNoteNodesForVisiblePart()[noteIndex].tapInTheMiddle()
        }
        app.typeText(text)
        return self
    }
}
