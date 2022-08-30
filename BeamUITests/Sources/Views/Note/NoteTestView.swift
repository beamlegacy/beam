//
//  NoteTestView.swift
//  BeamUITests
//
//  Created by Andrii on 26.07.2021.
//

import Foundation
import XCTest

class NoteTestView: TextEditorContextTestView {
    
    var noteTitle: XCUIElement {
        return app.windows.scrollViews[NoteViewLocators.ScrollViews.noteView.accessibilityIdentifier].textFields[NoteViewLocators.TextFields.noteTitle.accessibilityIdentifier]
    }
    var noteTitleStatic: XCUIElement {
        return app.windows.scrollViews[NoteViewLocators.ScrollViews.noteView.accessibilityIdentifier].staticTexts[NoteViewLocators.TextFields.noteTitle.accessibilityIdentifier]
    }
    
    @discardableResult
    func waitForNoteViewToLoad() -> Bool {
        return scrollView(NoteViewLocators.ScrollViews.noteView.accessibilityIdentifier)
            .waitForExistence(timeout: BaseTest.minimumWaitTimeout) && waitForNoteTitleToBeVisible()
    }
    
    @discardableResult
    func waitForTodayNoteViewToLoad() -> Bool {
        return scrollView(NoteViewLocators.ScrollViews.noteView.accessibilityIdentifier)
            .waitForExistence(timeout: BaseTest.minimumWaitTimeout) && waitForTodayNoteTitleToBeVisible()
    }

    @discardableResult
    func waitForNoteTitleToBeVisible() -> Bool {
        return app.textFields[NoteViewLocators.TextFields.noteTitle.accessibilityIdentifier]
            .waitForExistence(timeout: BaseTest.implicitWaitTimeout)
    }
    
    @discardableResult
    func waitForTodayNoteTitleToBeVisible() -> Bool {
        return staticText(NoteViewLocators.TextFields.noteTitle.accessibilityIdentifier)
            .waitForExistence(timeout: BaseTest.implicitWaitTimeout)
    }
    
    func getIndentationTriangleAtNode(nodeIndex: Int) -> XCUIElement {
        return getTextNodeByIndex(nodeIndex: nodeIndex).disclosureTriangles.firstMatch
    }
    
    func isIndentationTriangleOpened(nodeIndex: Int) -> Bool {
        return getIndentationTriangleAtNode(nodeIndex: nodeIndex).label.hasSuffix(" opened")
    }
    
    func isIndentationTriangleClosed(nodeIndex: Int) -> Bool {
        return getIndentationTriangleAtNode(nodeIndex: nodeIndex).label.hasSuffix(" closed")
    }
    
    func doesTextNodeHaveDisclosureTriangle(nodeIndex: Int) -> Bool {
        return getIndentationTriangleAtNode(nodeIndex: nodeIndex).exists
    }
    
    func getNumberOfDisclosureTriangles() -> Int {
        return app.disclosureTriangles.matching(identifier: NoteViewLocators.DisclosureTriangles.indentationArrow.accessibilityIdentifier).count
    }
    
    func getNoteTitle() -> String {
        return noteTitle.getStringValue()
    }
    
    func getNoteStaticTitle() -> String {
        return noteTitleStatic.getStringValue()
    }
    
    func getDeleteNoteButton() -> XCUIElement {
        return image(NoteViewLocators.Buttons.deleteNoteButton.accessibilityIdentifier)
    }
    
    func getNoteSwitcherButton(noteName: String) -> XCUIElement {
        return app.buttons.element(matching: NSPredicate(format: "identifier = '\(ToolbarLocators.Buttons.noteSwitcher.accessibilityIdentifier)' AND value = '\(noteName)'"))
    }
    
    func clickDeleteButton() -> AlertTestView {
        getDeleteNoteButton().clickOnHittable()
        return AlertTestView()
    }
    
    @discardableResult
    func makeNoteTitleEditable() -> XCUIElement {
        self.noteTitle.tapInTheMiddle()
        sleep(1) //to be removed when handling coursor appearance at card title
        self.noteTitle.tapInTheMiddle()
        return noteTitle
    }
    
    func getNewNoteCreationButton() -> XCUIElement {
        button(NoteViewLocators.Buttons.newNoteCreation.accessibilityIdentifier)
    }
    
    @discardableResult
    func clickNewNoteCreationButton() -> OmniBoxTestView {
        getNewNoteCreationButton().clickOnExistence()
        return OmniBoxTestView()
    }
    
    @discardableResult
    func publishNote() -> NoteTestView {
        waitForNoteViewToLoad()
        button(NoteViewLocators.Buttons.publishNoteButton.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    @discardableResult
    func unpublishNote() -> NoteTestView {
        waitForNoteViewToLoad()
        clickPublishedMenuDisclosureTriangle()
        app.staticTexts[NoteViewLocators.StaticTexts.unpublishLabel.accessibilityIdentifier].clickOnExistence()
        app.windows.sheets["alert"].buttons[NoteViewLocators.Buttons.unpublishNoteButton.accessibilityIdentifier].clickOnHittable()
        return self
    }
    
    @discardableResult
    func clickPublishedMenuDisclosureTriangle() -> NoteTestView {
        image(NoteViewLocators.DisclosureTriangles.editorArrowDown.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    @discardableResult
    func clickAddToProfileToggle() -> NoteTestView {
        app.staticTexts[NoteViewLocators.StaticTexts.addToProfile.accessibilityIdentifier].clickOnExistence()
        return self
    }
    
    @discardableResult
    func sharePublishedNoteMenuDisplay() -> NoteTestView {
        app.staticTexts[NoteViewLocators.StaticTexts.sharePublishedNote.accessibilityIdentifier].hoverInTheMiddle()
        return self
    }
    
    @discardableResult
    func sharePublishedNoteAction(_ item: NoteViewLocators.SharePublishedNote) -> NoteTestView {
        // hover first item to not dismiss the menu
        app.staticTexts[NoteViewLocators.SharePublishedNote.shareCopyUrl.accessibilityIdentifier].hoverInTheMiddle()
        app.staticTexts[item.accessibilityIdentifier].clickOnExistence()
        return self
    }
    
    func getNoteElementsQueryForVisiblePart() -> XCUIElementQuery {
        return app.windows.textViews.matching(identifier: NoteViewLocators.TextFields.textNode.accessibilityIdentifier)
    }

    func addNoteToProfile() -> NoteTestView {
        image(NoteViewLocators.DisclosureTriangles.editorArrowDown.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    func getNoteTextsForVisiblePart() -> [String] {
        let notesElements = getNoteNodesForVisiblePart()
        var names = [String]()
        for elem in notesElements {
            names.append(elem.getStringValue())
        }
        return names
    }
    
    func getNoteNodesElementQuery() -> XCUIElementQuery {
        return app.windows.textViews.matching(identifier:NoteViewLocators.TextFields.textNode.accessibilityIdentifier)
    }
    
    func getNumberOfVisibleNotes() -> Int {
        return self.getNoteNodesForVisiblePart().count
    }
    
    func navigateToWebView() {
        button(ToolbarLocators.Buttons.openWebButton.accessibilityIdentifier).clickOnExistence()
    }
    
    func getNumberOfImageNodes() -> Int {
        return self.getImageNodes().count
    }
    
    func getImageNodes() -> [XCUIElement] {
        return getImageNotesElementsQuery().allElementsBoundByIndex
    }
    
    func getImageNotesElementsQuery() -> XCUIElementQuery {
        return app.windows.textViews.matching(identifier: NoteViewLocators.TextFields.imageNode.accessibilityIdentifier)
    }
    
    func getImageNodeByIndex(nodeIndex: Int) -> XCUIElement {
        return self.getImageNodes()[nodeIndex]
    }
    
    func getNotesExpandButtons() -> [XCUIElement] {
        return app.windows.buttons.matching(identifier:  NoteViewLocators.Buttons.expandButton.accessibilityIdentifier).allElementsBoundByIndex
    }
    
    func getNotesExpandButtonsCount() -> Int {
        return self.getNotesExpandButtons().count
    }
    
    func getNoteExpandButtonByIndex(noteIndex: Int) -> XCUIElement {
        return self.getNotesExpandButtons()[noteIndex]
    }
    
    func getLinksRefExpandButton() -> [XCUIElement] {
        return app.windows.disclosureTriangles.matching(identifier:  NoteViewLocators.Buttons.linkRefExpandButton.accessibilityIdentifier).allElementsBoundByIndex
    }
    
    func getLinksRefExpandButtonCount() -> Int {
        return self.getLinksRefExpandButton().count
    }
    
    func getLinkRefExpandButtonByIndex(noteIndex: Int) -> XCUIElement {
        return self.getLinksRefExpandButton()[noteIndex]
    }
    
    func getLinkRefExpandedStatus(_ index: Int) -> String {
        return self.getLinksRefExpandButton()[index].label
    }
    
    func getLinksNoteRefExpandButton() -> [XCUIElement] {
        return app.windows.disclosureTriangles.matching(identifier:  NoteViewLocators.Buttons.linkRefNoteExpandButton.accessibilityIdentifier).allElementsBoundByIndex
    }
    
    func getLinksNoteRefExpandButtonCount() -> Int {
        return self.getLinksNoteRefExpandButton().count
    }
    
    func getLinkNoteRefExpandButtonByIndex(noteIndex: Int) -> XCUIElement {
        return self.getLinksNoteRefExpandButton()[noteIndex]
    }
    
    func getLinkNoteRefExpandedStatus(_ index: Int) -> String {
        return self.getLinksNoteRefExpandButton()[index].label
    }
    
    @discardableResult
    func clickNoteExpandButtonByIndex(noteIndex: Int) -> NoteTestView {
        self.getNoteExpandButtonByIndex(noteIndex: noteIndex).coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
        return self
    }

    func getTextNodes() -> [XCUIElement] {
        return getTextNodesElementsQuery().allElementsBoundByIndex
    }
    
    func getPivotButtonCounter() -> String {
        return button(ToolbarLocators.Buttons.openWebButton.accessibilityIdentifier).title
    }

    func getTextNodesElementsQuery() -> XCUIElementQuery {
        return app.windows.textViews.matching(identifier: NoteViewLocators.TextFields.textNode.accessibilityIdentifier)
    }

    func getTextNodeByIndex(nodeIndex: Int) -> XCUIElement {
        return self.getTextNodes()[nodeIndex]
    }

    func getEmbedNodes() -> [XCUIElement] {
        return getEmbedNodesElementsQuery().allElementsBoundByIndex
    }

    func getEmbedNodesElementsQuery() -> XCUIElementQuery {
        return app.windows.textViews.matching(identifier: NoteViewLocators.TextFields.embedNode.accessibilityIdentifier)
    }

    func getEmbedNodeByIndex(nodeIndex: Int) -> XCUIElement {
        return self.getEmbedNodes()[nodeIndex]
    }
    
    func getLinksNames() -> [XCUIElement] {
        return app.windows.buttons.matching(identifier: NoteViewLocators.Buttons.linkNamesButton.accessibilityIdentifier).allElementsBoundByIndex
    }
    
    func getLinksContentElement() -> [XCUIElement] {
        return app.windows.textViews.matching(identifier: NoteViewLocators.TextViews.linksRefsLabel.accessibilityIdentifier).allElementsBoundByIndex
    }

    func getFirstLinksContentElement() -> XCUIElement {
        let firstLink = app.windows.textViews.matching(identifier: NoteViewLocators.TextViews.linksRefsLabel.accessibilityIdentifier)
            .element
        XCTAssertTrue(firstLink.waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        return firstLink
    }
    
    func getLinksNamesNumber() -> Int {
        return self.getLinksNames().count
    }
    
    func getLinkContentByIndex(_ index: Int) -> String {
        return getLinksContentElement()[index].getStringValue()
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
        return app.windows.textViews.matching(identifier: NoteViewLocators.TextFields.textNode.accessibilityIdentifier).allElementsBoundByIndex
    }
    
    @discardableResult
    func openLinkByIndex(_ index: Int) -> NoteTestView {
        self.getLinksNames()[index].tapInTheMiddle()
        return self
    }
    
    @discardableResult
    func createBiDiLink(_ noteName: String, _ noteNumber: Int = 0) -> NoteTestView {
        let noteToBeTypedIn = getNoteNodesForVisiblePart()[noteNumber]
        app.typeText("@" + noteName)
        waitForStringValueEqual("@" + noteName, noteToBeTypedIn)
        typeKeyboardKey(.enter)
        return self
    }
    
    @discardableResult
    func createReference(_ noteName: String, _ noteNumber: Int = 0) -> NoteTestView {
        let noteToBeTypedIn = getNoteNodesForVisiblePart()[noteNumber]
        app.typeText(noteName)
        waitForStringValueEqual(noteName, noteToBeTypedIn)
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
        _ = otherElement(NoteViewLocators.Buttons.referencesSection.accessibilityIdentifier).buttons.matching(identifier: NoteViewLocators.Buttons.linkReferenceCounterTitle.accessibilityIdentifier).firstMatch.waitForExistence(timeout: BaseTest.minimumWaitTimeout)
        return otherElement(NoteViewLocators.Buttons.referencesSection.accessibilityIdentifier).buttons.matching(identifier: NoteViewLocators.Buttons.linkReferenceCounterTitle.accessibilityIdentifier).firstMatch
    }
    
    func getLinksCounterElement() -> XCUIElement {
        _ = otherElement(NoteViewLocators.Buttons.linksSection.accessibilityIdentifier).buttons.matching(identifier: NoteViewLocators.Buttons.linkReferenceCounterTitle.accessibilityIdentifier).firstMatch.waitForExistence(timeout: BaseTest.minimumWaitTimeout)
        return otherElement(NoteViewLocators.Buttons.linksSection.accessibilityIdentifier).buttons.matching(identifier: NoteViewLocators.Buttons.linkReferenceCounterTitle.accessibilityIdentifier).firstMatch
    }
    
    @discardableResult
    func expandReferenceSection() -> NoteTestView {
        self.getRefereceSectionCounterElement().tapInTheMiddle()
        return self
    }
    
    @discardableResult
    func linkAllReferences() -> NoteTestView {
        button(NoteViewLocators.Buttons.linkAllButton.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    func doesReferenceSectionExist() -> Bool {
        return self.getRefereceSectionCounterElement().waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    func getRefereceSectionCounterElement() -> XCUIElement {
        return otherElement(AllNotesViewLocators.Others.referenceSection.accessibilityIdentifier)
    }
    
    func getBlockRefs() -> XCUIElementQuery {
        _ = textView(NoteViewLocators.TextViews.blockReference.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout)
        return app.textViews.matching(identifier: NoteViewLocators.TextViews.blockReference.accessibilityIdentifier)
    }
    
    func getBlockRefByIndex(_ index: Int) -> XCUIElement {
        return self.getBlockRefs().element(boundBy: index)
    }
    
    func getNumberOfBlockRefs() -> Int {
        return self.getBlockRefs().count
    }
    
    func blockReferenceMenuActionTrigger(_ action: NoteViewLocators.StaticTexts, blockRefNumber: Int = 1) {
        XCUIElement.perform(withKeyModifiers: .control) {
            self.getBlockRefs().element(boundBy: blockRefNumber - 1).tapInTheMiddle()
        }
        staticText(action.accessibilityIdentifier).clickOnExistence()
    }
    
    @discardableResult
    func removeBlockRef(blockRefNumber: Int = 1) -> NoteTestView {
        self.blockReferenceMenuActionTrigger(.blockRefRemove, blockRefNumber: blockRefNumber)
        return self
    }
    
    @discardableResult
    func addTestRef(_ referenceText: String) -> NoteTestView {
        app.typeText("((\(referenceText))\r")
        return self
    }
    
    func triggerContextMenu(key: String) -> ContextMenuTestView {
        app.typeText("/")
        return ContextMenuTestView(key: key)
    }
    
    func isImageNodeCollapsed(nodeIndex: Int) -> Bool {
        return getImageNodeByIndex(nodeIndex: nodeIndex).buttons[NoteViewLocators.Buttons.imageNoteCollapsedView.accessibilityIdentifier].waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    func getImageNodeCollapsedTitle(nodeIndex: Int) -> String {
        return getImageNodeByIndex(nodeIndex: nodeIndex).buttons[NoteViewLocators.Buttons.imageNoteCollapsedView.accessibilityIdentifier].firstMatch.title
    }
    
    func waitForNoteToOpen(noteTitle: String) -> Bool {
        return waitForStringValueEqual(noteTitle, self.noteTitle, BaseTest.implicitWaitTimeout)
    }
    
    func getBreadCrumbElements() -> [XCUIElement] {
        return otherElement(NoteViewLocators.OtherElements.breadCrumb.accessibilityIdentifier).buttons.matching(identifier: NoteViewLocators.Buttons.breadcrumbTitle.accessibilityIdentifier).allElementsBoundByIndex
    }
    
    func waitForBreadcrumbs() -> Bool {
        return otherElement(NoteViewLocators.OtherElements.breadCrumb.accessibilityIdentifier).buttons.matching(identifier: NoteViewLocators.Buttons.breadcrumbTitle.accessibilityIdentifier).firstMatch.waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    func getBreadCrumbElementsNumber() -> Int {
        return self.getBreadCrumbElements().count
    }
    
    func getBreadCrumbTitleByIndex(_ index: Int) -> String {
        return self.getBreadCrumbElements()[index].title
    }
    
    func getCheckboxAtTextNote(_ noteNumber: Int) -> XCUIElement {
        let index = noteNumber - 1
        return getTextNodeByIndex(nodeIndex: index).buttons[NoteViewLocators.Buttons.checkbox.accessibilityIdentifier]
    }
    
    func getAddToProfileToggleElement() -> XCUIElement {
        return app.otherElements[NoteViewLocators.OtherElements.addToProfileToggle.accessibilityIdentifier].firstMatch
    }
    
    func getStagingProfileLinkElement() -> XCUIElement {
        let staginEnvPredicate = NSPredicate(format: "value BEGINSWITH '\(BaseTest().stagingEnvironmentServerAddress)'")
        return app.staticTexts.matching(staginEnvPredicate).firstMatch
    }
    
    @discardableResult
    func createCheckboxAtNote(_ noteNumber: Int) -> XCUIElement {
        let index = noteNumber - 1
        let checkboxShortcut = "-[]"
        typeInNoteNodeByIndex(noteIndex: index, text: checkboxShortcut, needsActivation: true)
        return getTextNodeByIndex(nodeIndex: index)
    }
    
    func nodeLineFormatChange(_ format: TextFormat) {
        switch format {
        case .bold:
            self.nodeLineFormatTrigger("**")
        case .italic:
            self.nodeLineFormatTrigger("*")
        case .strikethrough:
            self.nodeLineFormatTrigger("~~")
        case .underline:
            self.nodeLineFormatTrigger("_")
        case .heading1:
            shortcutHelper.shortcutActionInvoke(action: .beginOfNote)
            self.app.typeText("#")
            self.typeKeyboardKey(.space)
        case .heading2:
            shortcutHelper.shortcutActionInvoke(action: .beginOfNote)
            self.app.typeText("##")
            self.typeKeyboardKey(.space)
        }
    }
    
    private func nodeLineFormatTrigger(_ key: String) {
        shortcutHelper.shortcutActionInvoke(action: .beginOfNote)
        app.typeText(key)
        shortcutHelper.shortcutActionInvoke(action: .endOfLine)
        app.typeText(key)
    }
    
    enum TextFormat: CaseIterable {
        case bold
        case italic
        case strikethrough
        case underline
        case heading1
        case heading2
    }
    
    @discardableResult
    func pinUnpinNote() -> NoteTestView {
        image(NoteViewLocators.Buttons.pinUnpinButton.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    @discardableResult
    func getNumberOfPinnedNotes() -> Int {
        let number = app.buttons.matching(identifier: ToolbarLocators.Buttons.noteSwitcher.accessibilityIdentifier).count
        return number
    }
    
    func isBulletVisible() -> Bool {
        return getFirstBulletElement().waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    func getFirstBulletElement() -> XCUIElement {
        return app.buttons[NoteViewLocators.Buttons.bullet.accessibilityIdentifier]
    }
    
    func getNumberOfVisibleBullets() -> Int {
        return isBulletVisible() ? app.buttons.matching(identifier: NoteViewLocators.Buttons.bullet.accessibilityIdentifier).count : 0
    }
    
    private let anyTabGroupPredicate = NSPredicate(format: "identifier BEGINSWITH '\(NoteViewLocators.Groups.tabGroupPrefix.accessibilityIdentifier)'")
    
    func getTabGroupElementIndex(index: Int) -> XCUIElement {
        return app.windows.groups.matching(anyTabGroupPredicate).element(boundBy: index)
    }
    
    func getTabGroupCount() -> Int {
        return app.windows.groups.matching(anyTabGroupPredicate).count
    }
    
    func isTabGroupDisplayed(index: Int) -> Bool {
        return getTabGroupElementIndex(index: index).waitForExistence(timeout: minimumWaitTimeout)
    }
    
    func getTabGroupElementName(index: Int) -> String {
        return getTabGroupElementIndex(index: index).label
    }
    
    func openTabGroup(index: Int) {
        if BaseTest().isBigSurOS(){
            getTabGroupElementIndex(index: index).children(matching: .other).firstMatch.clickInTheMiddle()
        } else {
            getTabGroupElementIndex(index: index).children(matching: .button).firstMatch.clickInTheMiddle()
        }
    }
    
    @discardableResult
    func openTabGroupMenu(index: Int) -> TabGroupMenuView {
        _ = getTabGroupElementIndex(index: index).waitForExistence(timeout: implicitWaitTimeout)
        getTabGroupElementIndex(index: index).children(matching: .staticText).firstMatch.hoverInTheMiddle()
        getTabGroupElementIndex(index: index).rightClickInTheMiddle()
        return TabGroupMenuView()
    }
    
    func getTabGroupNameOfWindow(index: Int) -> String {
        return app.windows.element(boundBy: index).staticTexts[TabGroupMenuViewLocators.MenuItems.tabGroupCapsuleName.accessibilityIdentifier].getStringValue()
    }
    
}
