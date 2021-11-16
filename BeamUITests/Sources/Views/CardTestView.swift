//
//  CardView.swift
//  BeamUITests
//
//  Created by Andrii on 26.07.2021.
//

import Foundation
import XCTest

class CardTestView: BaseView {
    
    var cardTitle: XCUIElement { return textField(CardViewLocators.TextFields.cardTitle.accessibilityIdentifier)}

    @discardableResult
    func waitForCardViewToLoad() -> Bool {
        return scrollView(CardViewLocators.ScrollViews.noteView.accessibilityIdentifier)
            .waitForExistence(timeout: implicitWaitTimeout)
    }
    
    func openEditorOptions() {
        image(CardViewLocators.Buttons.editorOptions.accessibilityIdentifier).click()
    }
    
    func getCardTitle() -> String {
        return getElementStringValue(element: cardTitle)
    }
    
    func clickDeleteButton() -> AlertTestView {
        image(CardViewLocators.Buttons.deleteCardButton.accessibilityIdentifier).clickOnExistence()
        return AlertTestView()
    }
    
    @discardableResult
    func makeCardTitleEditable() -> XCUIElement {
        self.cardTitle.tapInTheMiddle()
        sleep(1) //to be removed when handling coursor appearance at card title
        self.cardTitle.tapInTheMiddle()
        return cardTitle
    }
    
    @discardableResult
    func publishCard() -> CardTestView {
        button(CardViewLocators.Buttons.publishCardButton.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    @discardableResult
    func unpublishCard() -> CardTestView {
        image(CardViewLocators.Buttons.editorButton.accessibilityIdentifier).click()
        _ = staticText(CardViewLocators.StaticTexts.unpublishLabel.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout)
        staticText(CardViewLocators.StaticTexts.unpublishLabel.accessibilityIdentifier).click()
        return self
    }
    
    func getCardNotesForVisiblePart() -> [XCUIElement] {
        return app.windows.textViews.matching(identifier: CardViewLocators.TextFields.noteField.accessibilityIdentifier).allElementsBoundByIndex
    }
    
    func getCardNotesElementQueryForVisiblePart() -> XCUIElementQuery {
        return app.windows.textViews.matching(identifier: CardViewLocators.TextFields.noteField.accessibilityIdentifier)
    }
    
    func getNumberOfVisibleNotes() -> Int {
        return getCardNotesForVisiblePart().count
    }
    
    func getCardNoteValueByIndex(_ index: Int) -> String {
        return getCardNoteElementByIndex(index).value as? String ?? errorFetchStringValue
    }
    
    func getCardNoteElementByIndex(_ index: Int) -> XCUIElement {
        return getCardNotesForVisiblePart()[index]
    }
    
    @discardableResult
    func typeInCardNoteByIndex(noteIndex: Int, text: String, needsActivation: Bool = false) -> CardTestView {
        if needsActivation {
            getCardNotesForVisiblePart()[noteIndex].tapInTheMiddle()
        }
        app.typeText(text)
        return self
    }
    
    func navigateToWebView() {
        button(OmniBarLocators.Buttons.openWebButton.accessibilityIdentifier).click()
    }
    
    func getNumberOfImageNotes() -> Int {
        return getImageNotes().count
    }
    
    func getImageNotes() -> XCUIElementQuery {
        return app.windows.textViews.matching(identifier:  CardViewLocators.TextFields.imageNote.accessibilityIdentifier)
    }
    
    func getLinksNames() -> [XCUIElement] {
        return app.windows.buttons.matching(identifier: CardViewLocators.Buttons.linkNamesButton.accessibilityIdentifier).allElementsBoundByIndex
    }
    
    func getLinksContent() -> [XCUIElement] {
        return app.windows.textViews.matching(identifier: CardViewLocators.TextViews.linksRefsLabel.accessibilityIdentifier).allElementsBoundByIndex
    }
    
    func getLinksNamesNumber() -> Int {
        return getLinksNames().count
    }
    
    func getLinkContentByIndex(_ index: Int) -> String {
        return getElementStringValue(element: getLinksContent()[index])
    }
    
    func getLinkNameByIndex(_ index: Int) -> String {
        return getLinksNames()[index].title
    }
    
    func getLinksContentNumber() -> Int {
        return getLinksContent().count
    }
    
    func getReferences() -> [XCUIElement] {
        return app.windows.textViews.matching(identifier: CardViewLocators.TextFields.noteField.accessibilityIdentifier).allElementsBoundByIndex
    }
    
    @discardableResult
    func openBiDiLink(_ linkName: String) -> CardTestView {
        button(linkName).tapInTheMiddle()
        return self
    }
    
    @discardableResult
    func openBiDiLink(_ index: Int) -> CardTestView {
        app.buttons.matching(identifier: "internalLink").element(boundBy: index).tapInTheMiddle()
        return self
    }
    
    @discardableResult
    func openLinkByIndex(_ index: Int) -> CardTestView {
        getLinksNames()[index].tapInTheMiddle()
        return self
    }
    
    @discardableResult
    func createBiDiLink(_ cardName: String, _ noteNumber: Int = 0) -> CardTestView {
        let noteToBeTypedIn = getCardNotesForVisiblePart()[noteNumber]
        app.typeText("@" + cardName)
        WaitHelper().waitForStringValueEqual("@" + cardName, noteToBeTypedIn)
        typeKeyboardKey(.enter)
        return self
    }
    
    @discardableResult
    func createReference(_ cardName: String, _ noteNumber: Int = 0) -> CardTestView {
        let noteToBeTypedIn = getCardNotesForVisiblePart()[noteNumber]
        app.typeText(cardName)
        WaitHelper().waitForStringValueEqual(cardName, noteToBeTypedIn)
        typeKeyboardKey(.enter)
        return self
    }
    
    @discardableResult
    func clickDisclosureTriangleByIndex(_ index: Int = 0) -> CardTestView {
        let element = getDisclosureTriangles().element(boundBy: index)
        element.tapInTheMiddle()
        return self
    }
    
    func getDisclosureTriangles() -> XCUIElementQuery {
        return app.disclosureTriangles
            .matching(identifier: AllCardsViewLocators.Others.disclosureTriangle.accessibilityIdentifier)
            .matching(NSPredicate(format: WaitHelper.PredicateFormat.isHittable.rawValue))
    }
    
    func getCountOfDisclosureTriangles() -> Int {
        return getDisclosureTriangles().count
    }
    
    @discardableResult
    func expandReferenceSection() -> CardTestView {
        otherElement(AllCardsViewLocators.Others.referenceSection.accessibilityIdentifier).tapInTheMiddle()
        return self
    }
    
    func getBlockRefs() -> XCUIElementQuery {
        _ = textView(CardViewLocators.TextViews.blockReference.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout)
        return app.textViews.matching(identifier: CardViewLocators.TextViews.blockReference.accessibilityIdentifier)
    }
    
    func getBlockRefByIndex(_ index: Int) -> XCUIElement {
        return getBlockRefs().element(boundBy: index)
    }
    
    func getNumberOfBlockRefs() -> Int {
        return getBlockRefs().count
    }
    
    func blockReferenceMenuActionTrigger(_ action: CardViewLocators.StaticTexts, blockRefNumber: Int = 1) {
        XCUIElement.perform(withKeyModifiers: .control) {
            getBlockRefs().element(boundBy: blockRefNumber - 1).tapInTheMiddle()
        }
        staticText(action.accessibilityIdentifier).clickOnExistence()
    }
    
    @discardableResult
    func removeBlockRef(blockRefNumber: Int = 1) -> CardTestView {
        blockReferenceMenuActionTrigger(.blockRefRemove, blockRefNumber: blockRefNumber)
        return self
    }
    
    @discardableResult
    func addTestRef(_ referenceText: String) -> CardTestView {
        app.typeText("((\(referenceText))\r")
        return self
    }
}
