//
//  TabGroupMenuView.swift
//  BeamUITests
//
//  Created by Quentin Valero on 13/07/2022.
//

import Foundation
import XCTest

class TabGroupMenuView: BaseView {
    
    private let anyTabGroupPredicate = NSPredicate(format: "identifier BEGINSWITH '\(TabGroupMenuViewLocators.TabGroups.tabGroupPrefix.accessibilityIdentifier)'")
    
    func getTabGroupElementIndex(index: Int) -> XCUIElement {
        return app.windows.groups.matching(anyTabGroupPredicate).element(boundBy: index)
    }
    
    func getTabGroupCount() -> Int {
        return app.windows.groups.matching(anyTabGroupPredicate).count
    }
    
    @discardableResult
    func getTabGroupWithName(tabGroupName: String) -> XCUIElement {
        app.windows.groups.matching(NSPredicate(format: "identifier BEGINSWITH '\(TabGroupMenuViewLocators.TabGroups.tabGroupPrefix.accessibilityIdentifier)Group(" + tabGroupName + ")'")).firstMatch
    }
    
    func isTabGroupDisplayed(index: Int) -> Bool {
        return getTabGroupElementIndex(index: index).waitForExistence(timeout: minimumWaitTimeout)
    }
    
    @discardableResult
    func openTabGroupMenu(index: Int) -> TabGroupMenuView {
        getTabGroupElementIndex(index: index).rightClickInTheMiddle()
        return self
    }
    
    @discardableResult
    func openTabGroupMenuWithName(tabGroupName: String) -> TabGroupMenuView {
        getTabGroupWithName(tabGroupName: tabGroupName).rightClickInTheMiddle()
        return self
    }
    
    @discardableResult
    func waitForMenuToBeDisplayed() -> Bool {
        return textField(TabGroupMenuViewLocators.MenuItems.tabGroupName.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    @discardableResult
    func waitForTabGroupNameToBeDisplayed(tabGroupName: String) -> Bool {
        return getTabGroupWithName(tabGroupName: tabGroupName).waitForExistence(timeout: BaseTest.implicitWaitTimeout)
    }
    
    @discardableResult
    func waitForTabGroupToBeDisplayed(index: Int) -> Bool {
        return getTabGroupElementIndex(index: index).waitForExistence(timeout: BaseTest.implicitWaitTimeout)
    }
    
    @discardableResult
    func setTabGroupName(tabGroupName: String) -> TabGroupMenuView {
        let tabGroupNameElement = textField(TabGroupMenuViewLocators.MenuItems.tabGroupName.accessibilityIdentifier)
        tabGroupNameElement.clickOnExistence()
        tabGroupNameElement.typeText(tabGroupName)
        self.typeKeyboardKey(.enter)
        waitForDoesntExist(tabGroupNameElement)
        return self
    }
    
    @discardableResult
    func deleteTabGroupName() -> TabGroupMenuView {
        textField(TabGroupMenuViewLocators.MenuItems.tabGroupName.accessibilityIdentifier).clickOnExistence()
        shortcutHelper.shortcutActionInvoke(action: .selectAll)
        self.typeKeyboardKey(.delete)
        self.typeKeyboardKey(.enter)
        return self
    }
    
    @discardableResult
    func renameExistingTabGroupName(tabGroupName: String) -> TabGroupMenuView {
        let tabGroupNameElement = textField(TabGroupMenuViewLocators.MenuItems.tabGroupName.accessibilityIdentifier).clickOnExistence()
        tabGroupNameElement.clickOnExistence()
        shortcutHelper.shortcutActionInvoke(action: .selectAll)
        tabGroupNameElement.typeText(tabGroupName)
        self.typeKeyboardKey(.enter)
        waitForDoesntExist(tabGroupNameElement)
        return self
    }
    
    @discardableResult
    func getTabGroupName() -> String {
        return staticText(TabGroupMenuViewLocators.MenuItems.tabGroupCapsuleName.accessibilityIdentifier).getStringValue()
    }
    
    @discardableResult
    func clickTabGroupMenu(_ item: TabGroupMenuViewLocators.MenuItems) -> TabGroupMenuView {
        menuItem(item.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    @discardableResult
    func clickTabGroupCapsule(index: Int) -> TabGroupMenuView {
        getTabGroupElementIndex(index: index).clickInTheMiddle()
        return self
    }
    
    func collapseTabGroup(index: Int) {
        openTabGroupMenu(index: index)
        waitForMenuToBeDisplayed()
        clickTabGroupMenu(.tabGroupCollapse)
    }
    
    func expandTabGroup(index: Int) {
        openTabGroupMenu(index: index)
        waitForMenuToBeDisplayed()
        clickTabGroupMenu(.tabGroupExpand)
    }
    
    func closeTabGroup(index: Int) {
        openTabGroupMenu(index: index)
        waitForMenuToBeDisplayed()
        clickTabGroupMenu(.tabGroupCloseGroup)
    }
    
    func captureTabGroup(index: Int, destinationNote: String? = nil) {
        openTabGroupMenu(index: index)
        waitForMenuToBeDisplayed()
        clickTabGroupMenu(.tabGroupCapture)
        if destinationNote != nil {
            let destinationNoteField = app.windows.textFields.matching(identifier: PnSViewLocators.TextFields.shootCardPickerTextField.accessibilityIdentifier).firstMatch
            _ = destinationNoteField.waitForExistence(timeout: BaseTest.minimumWaitTimeout)
            destinationNoteField.clickAndType(destinationNote!)
        }
        typeKeyboardKey(.enter)
        typeKeyboardKey(.escape)
    }
    
    @discardableResult
    func waitForShareMenuToBeDisplayed() -> Bool {
        return menuItem(TabGroupMenuViewLocators.ShareTabGroupMenu.shareCopyLink.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    func isShareTabMenuDisplayed() -> Bool {
        waitForShareMenuToBeDisplayed()
        var result = true
        for item in TabGroupMenuViewLocators.ShareTabGroupMenu.allCases {
            result = result && menuItem(item.accessibilityIdentifier).isEnabled
        }
        return result
    }
    
    @discardableResult
    func shareTabGroupAction(_ item: String) -> WebTestView {
        // hover first item to not dismiss the menu
        app.menuItems[TabGroupMenuViewLocators.ShareTabGroupMenu.shareCopyLink.accessibilityIdentifier].hoverInTheMiddle()
        app.menuItems[item].clickOnExistence()
        return WebTestView()
    }
    
    func isTabGroupLinkInPasteboard() -> Bool {
        let regex = try! NSRegularExpression(pattern: "https://staging-web-server.ew.r.appspot.com/.*/.*")
        let pasteboardContent = NSPasteboard.general.pasteboardItems?.first?.string(forType: NSPasteboard.PasteboardType.string)
        let range = NSRange(location: 0, length: pasteboardContent!.utf16.count)
        return regex.firstMatch(in: pasteboardContent!, options: [], range: range) != nil
    }
}
