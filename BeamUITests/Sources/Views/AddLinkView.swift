//
//  AddLinkView.swift
//  BeamUITests
//
//  Created by Quentin Valero on 06/06/2022.
//

import Foundation
import XCTest

class AddLinkView: BaseView {
    
    @discardableResult
    func waitForLinkEditorPopUpAppear() -> Bool {
        return getLinkElement().waitForExistence(timeout: TimeInterval(2))
    }
    
    func getLinkElement() -> XCUIElement{
        return app.dialogs.textFields[AddLinkViewLocators.TextFields.linkUrl.accessibilityIdentifier]
    }
    
    func getTitleEmptyElement() -> XCUIElement{
        return app.dialogs.textFields[AddLinkViewLocators.TextFields.linkTitleEmpty.accessibilityIdentifier]
    }
    
    func getCopyLinkElement() -> XCUIElement{
        return app.images[AddLinkViewLocators.Images.copyIcon.accessibilityIdentifier]
    }
    
    func getLink() -> String {
        return getElementStringValue(element: getLinkElement())
    }
    
    func clickOnTitleCell(title: String) -> XCUIElement {
        return app.dialogs.textFields[title].clickOnExistence()
    }
    
    @discardableResult
    func clickOnCopyLinkElement() -> AddLinkView {
        self.getCopyLinkElement().clickOnExistence()
        return self
    }
    
    func isCopyLinkIconDisplayed() -> Bool {
        return self.getCopyLinkElement().exists
    }
    
    func isLinkCopiedLabelDisplayed() -> Bool {
        return XCUIApplication().dialogs.staticTexts[CardViewLocators.StaticTexts.linkCopiedLabel.accessibilityIdentifier].exists
    }
}
