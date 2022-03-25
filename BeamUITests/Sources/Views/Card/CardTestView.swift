//
//  CardView.swift
//  BeamUITests
//
//  Created by Andrii on 26.07.2021.
//

import Foundation
import XCTest

class CardTestView: BaseView {
    
    var cardTitle: XCUIElement { return textField(CardViewLocators.TextFields.noteTitle.accessibilityIdentifier)}
    var cardTitleStatic: XCUIElement { return staticText(CardViewLocators.TextFields.noteTitle.accessibilityIdentifier)}

    @discardableResult
    func waitForCardViewToLoad() -> Bool {
        return scrollView(CardViewLocators.ScrollViews.noteView.accessibilityIdentifier)
            .waitForExistence(timeout: BaseTest.implicitWaitTimeout)
    }

    @discardableResult
    func waitForCardTitleToBeVisible() -> Bool {
        return scrollView(CardViewLocators.TextFields.noteTitle.accessibilityIdentifier)
            .waitForExistence(timeout: BaseTest.implicitWaitTimeout)
    }
    
    /*Deprecated 
    func openEditorOptions() {
        image(CardViewLocators.Buttons.editorOptions.accessibilityIdentifier).click()
    }*/
    
    func getCardTitle() -> String {
        return self.getElementStringValue(element: cardTitle)
    }
    
    func getCardStaticTitle() -> String {
        return self.getElementStringValue(element: cardTitleStatic)
    }
    
    func clickDeleteButton() -> AlertTestView {
        image(CardViewLocators.Buttons.deleteCardButton.accessibilityIdentifier).clickOnHittable()
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
        _ = staticText(CardViewLocators.StaticTexts.unpublishLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout)
        staticText(CardViewLocators.StaticTexts.unpublishLabel.accessibilityIdentifier).click()
        return self
    }
    
    func getCardNotesForVisiblePart() -> [XCUIElement] {
        return app.windows.textViews.matching(identifier: CardViewLocators.TextFields.textNode.accessibilityIdentifier).allElementsBoundByIndex
    }
    
    func getCardNotesElementQueryForVisiblePart() -> XCUIElementQuery {
        return app.windows.textViews.matching(identifier: CardViewLocators.TextFields.textNode.accessibilityIdentifier)
    }
    
    func getCardNotesTextForVisiblePart() -> [String] {
        let notesElements = getCardNotesForVisiblePart()
        var names = [String]()
        for elem in notesElements {
            names.append(getElementStringValue(element: elem))
        }
        return names
    }
    
    func getNumberOfVisibleNotes() -> Int {
        return self.getCardNotesForVisiblePart().count
    }
    
    func getCardNoteValueByIndex(_ index: Int) -> String {
        return self.getElementStringValue(element:  getCardNoteElementByIndex(index))
    }
    
    func getCardNoteElementByIndex(_ index: Int) -> XCUIElement {
        return self.getCardNotesForVisiblePart()[index]
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
        button(ToolbarLocators.Buttons.openWebButton.accessibilityIdentifier).click()
    }
    
    func getNumberOfImageNodes() -> Int {
        return self.getImageNodes().count
    }
    
    func getImageNodes() -> [XCUIElement] {
        return getImageNotesElementsQuery().allElementsBoundByIndex
    }
    
    func getImageNotesElementsQuery() -> XCUIElementQuery {
        return app.windows.textViews.matching(identifier: CardViewLocators.TextFields.imageNode.accessibilityIdentifier)
    }
    
    func getImageNodeByIndex(nodeIndex: Int) -> XCUIElement {
        return self.getImageNodes()[nodeIndex]
    }
    
    func getNotesExpandButtons() -> [XCUIElement] {
        return app.windows.buttons.matching(identifier:  CardViewLocators.Buttons.expandButton.accessibilityIdentifier).allElementsBoundByIndex
    }
    
    func getNotesExpandButtonsCount() -> Int {
        return self.getNotesExpandButtons().count
    }
    
    func getNoteExpandButtonByIndex(noteIndex: Int) -> XCUIElement {
        return self.getNotesExpandButtons()[noteIndex]
    }
    
    @discardableResult
    func clickNoteExpandButtonByIndex(noteIndex: Int) -> CardTestView {
        self.getNoteExpandButtonByIndex(noteIndex: noteIndex).coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
        return self
    }

    func getTextNodes() -> [XCUIElement] {
        return getTextNodesElementsQuery().allElementsBoundByIndex
    }

    func getTextNodesElementsQuery() -> XCUIElementQuery {
        return app.windows.textViews.matching(identifier: CardViewLocators.TextFields.textNode.accessibilityIdentifier)
    }

    func getTextNodeByIndex(nodeIndex: Int) -> XCUIElement {
        return self.getTextNodes()[nodeIndex]
    }

    func getEmbedNodes() -> [XCUIElement] {
        return getEmbedNodesElementsQuery().allElementsBoundByIndex
    }

    func getEmbedNodesElementsQuery() -> XCUIElementQuery {
        return app.windows.textViews.matching(identifier: CardViewLocators.TextFields.embedNode.accessibilityIdentifier)
    }

    func getEmbedNodeByIndex(nodeIndex: Int) -> XCUIElement {
        return self.getEmbedNodes()[nodeIndex]
    }
    
    func getLinksNames() -> [XCUIElement] {
        return app.windows.buttons.matching(identifier: CardViewLocators.Buttons.linkNamesButton.accessibilityIdentifier).allElementsBoundByIndex
    }
    
    func getLinksContentElement() -> [XCUIElement] {
        return app.windows.textViews.matching(identifier: CardViewLocators.TextViews.linksRefsLabel.accessibilityIdentifier).allElementsBoundByIndex
    }

    func getFirstLinksContentElement() -> XCUIElement {
        let firstLink = app.windows.textViews.matching(identifier: CardViewLocators.TextViews.linksRefsLabel.accessibilityIdentifier)
            .element
        XCTAssertTrue(firstLink.waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        return firstLink
    }
    
    func getLinksNamesNumber() -> Int {
        return self.getLinksNames().count
    }
    
    func getLinkContentByIndex(_ index: Int) -> String {
        return self.getElementStringValue(element: getLinksContentElement()[index])
    }
    
    func getLinkContentElementByIndex(_ index: Int) -> XCUIElement {
        return getLinksContentElement()[index]
    }
    
    func getLinkNameByIndex(_ index: Int) -> String {
        return self.getLinksNames()[index].title
    }
    
    func getLinksContentNumber() -> Int {
        return self.getLinksContentElement().count
    }
    
    func getReferences() -> [XCUIElement] {
        return app.windows.textViews.matching(identifier: CardViewLocators.TextFields.textNode.accessibilityIdentifier).allElementsBoundByIndex
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
        self.getLinksNames()[index].tapInTheMiddle()
        return self
    }
    
    @discardableResult
    func createBiDiLink(_ cardName: String, _ noteNumber: Int = 0) -> CardTestView {
        let noteToBeTypedIn = getCardNotesForVisiblePart()[noteNumber]
        app.typeText("@" + cardName)
        waitForStringValueEqual("@" + cardName, noteToBeTypedIn)
        typeKeyboardKey(.enter)
        return self
    }
    
    @discardableResult
    func createReference(_ cardName: String, _ noteNumber: Int = 0) -> CardTestView {
        let noteToBeTypedIn = getCardNotesForVisiblePart()[noteNumber]
        app.typeText(cardName)
        waitForStringValueEqual(cardName, noteToBeTypedIn)
        typeKeyboardKey(.enter)
        return self
    }
    
    func assertLinksCounterTitle(expectedNumber: Int) {
        let linksPostfix = expectedNumber == 1 ? " Link" : " Links"
        XCTAssertEqual("\(expectedNumber)\(linksPostfix)", getLinksCounterElement().title, "\(getLinksCounterElement().title) is not equal to expected \(expectedNumber) number")
    }
    
    func assertReferenceCounterTitle(expectedNumber: Int) {
        let referencesPostfix = expectedNumber == 1 ? " Reference" : " References"
        XCTAssertEqual("\(expectedNumber)\(referencesPostfix)", getReferencesCounterElement().title, "\(getReferencesCounterElement().title) is not equal to expected \(expectedNumber) number")
    }
    
    func getReferencesCounterElement() -> XCUIElement {
        _ = otherElement(CardViewLocators.Buttons.referencesSection.accessibilityIdentifier).buttons.matching(identifier: CardViewLocators.Buttons.linkReferenceCounterTitle.accessibilityIdentifier).firstMatch.waitForExistence(timeout: BaseTest.minimumWaitTimeout)
        return otherElement(CardViewLocators.Buttons.referencesSection.accessibilityIdentifier).buttons.matching(identifier: CardViewLocators.Buttons.linkReferenceCounterTitle.accessibilityIdentifier).firstMatch
    }
    
    func getLinksCounterElement() -> XCUIElement {
        _ = otherElement(CardViewLocators.Buttons.linksSection.accessibilityIdentifier).buttons.matching(identifier: CardViewLocators.Buttons.linkReferenceCounterTitle.accessibilityIdentifier).firstMatch.waitForExistence(timeout: BaseTest.minimumWaitTimeout)
        return otherElement(CardViewLocators.Buttons.linksSection.accessibilityIdentifier).buttons.matching(identifier: CardViewLocators.Buttons.linkReferenceCounterTitle.accessibilityIdentifier).firstMatch
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
            .matching(NSPredicate(format: PredicateFormat.isHittable.rawValue))
    }
    
    func getCountOfDisclosureTriangles() -> Int {
        return self.getDisclosureTriangles().count
    }
    
    @discardableResult
    func expandReferenceSection() -> CardTestView {
        self.getRefereceSectionCounterElement().tapInTheMiddle()
        return self
    }
    
    @discardableResult
    func linkAllReferences() -> CardTestView {
        button(CardViewLocators.Buttons.linkAllButton.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    func doesReferenceSectionExist() -> Bool {
        return self.getRefereceSectionCounterElement().waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    func getRefereceSectionCounterElement() -> XCUIElement {
        return otherElement(AllCardsViewLocators.Others.referenceSection.accessibilityIdentifier)
    }
    
    func getBlockRefs() -> XCUIElementQuery {
        _ = textView(CardViewLocators.TextViews.blockReference.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout)
        return app.textViews.matching(identifier: CardViewLocators.TextViews.blockReference.accessibilityIdentifier)
    }
    
    func getBlockRefByIndex(_ index: Int) -> XCUIElement {
        return self.getBlockRefs().element(boundBy: index)
    }
    
    func getNumberOfBlockRefs() -> Int {
        return self.getBlockRefs().count
    }
    
    func blockReferenceMenuActionTrigger(_ action: CardViewLocators.StaticTexts, blockRefNumber: Int = 1) {
        XCUIElement.perform(withKeyModifiers: .control) {
            self.getBlockRefs().element(boundBy: blockRefNumber - 1).tapInTheMiddle()
        }
        staticText(action.accessibilityIdentifier).clickOnExistence()
    }
    
    @discardableResult
    func removeBlockRef(blockRefNumber: Int = 1) -> CardTestView {
        self.blockReferenceMenuActionTrigger(.blockRefRemove, blockRefNumber: blockRefNumber)
        return self
    }
    
    @discardableResult
    func addTestRef(_ referenceText: String) -> CardTestView {
        app.typeText("((\(referenceText))\r")
        return self
    }
    
    func triggerContextMenu(key: String) -> ContextMenuTestView {
        app.typeText("/")
        return ContextMenuTestView(key: key)
    }
    
    func isImageNodeCollapsed(nodeIndex: Int) -> Bool {
        return getImageNodeByIndex(nodeIndex: nodeIndex).buttons[CardViewLocators.Buttons.imageNoteCollapsedView.accessibilityIdentifier].waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    func getImageNodeCollapsedTitle(nodeIndex: Int) -> String {
        return getImageNodeByIndex(nodeIndex: nodeIndex).buttons[CardViewLocators.Buttons.imageNoteCollapsedView.accessibilityIdentifier].firstMatch.title
    }
    
    func waitForCardToOpen(cardTitle: String) -> Bool {
        return waitForStringValueEqual(cardTitle, self.cardTitle, BaseTest.implicitWaitTimeout)
    }
    
    func getBreadCrumbElements() -> [XCUIElement] {
        return otherElement(CardViewLocators.OtherElements.breadCrumb.accessibilityIdentifier).buttons.matching(identifier: CardViewLocators.Buttons.breadcrumbTitle.accessibilityIdentifier).allElementsBoundByIndex
    }
    
    func waitForBreadcrumbs() -> Bool {
        return otherElement(CardViewLocators.OtherElements.breadCrumb.accessibilityIdentifier).buttons.matching(identifier: CardViewLocators.Buttons.breadcrumbTitle.accessibilityIdentifier).firstMatch.waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    func getBreadCrumbElementsNumber() -> Int {
        return self.getBreadCrumbElements().count
    }
    
    func getBreadCrumbTitleByIndex(_ index: Int) -> String {
        return self.getBreadCrumbElements()[index].title
    }
}
