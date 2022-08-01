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
    
    @discardableResult
    func getFirstTabGroup() -> XCUIElement {
        app.windows.groups.matching(anyTabGroupPredicate).firstMatch
    }
    
    @discardableResult
    func getTabGroupWithName(tabGroupName: String) -> XCUIElement {
        app.windows.groups.matching(NSPredicate(format: "identifier BEGINSWITH '\(TabGroupMenuViewLocators.TabGroups.tabGroupPrefix.accessibilityIdentifier)Group(" + tabGroupName + ")'")).firstMatch
    }
    
    @discardableResult
    func doesTabGroupExist() -> Bool {
        return waitForDoesntExist(app.windows.groups.matching(anyTabGroupPredicate).firstMatch)
    }
    
    @discardableResult
    func openFirstTabGroupMenu() -> TabGroupMenuView {
        getFirstTabGroup().rightClickInTheMiddle()
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
    func getTabGroupName() -> String {
        return staticText(TabGroupMenuViewLocators.MenuItems.tabGroupCapsuleName.accessibilityIdentifier).getStringValue()
    }
    
    func clickTabGroupMenu(_ item: TabGroupMenuViewLocators.MenuItems) {
        menuItem(item.accessibilityIdentifier).clickOnExistence()
    }
    
    func collapseFirstTabGroup() {
        openFirstTabGroupMenu()
        waitForMenuToBeDisplayed()
        clickTabGroupMenu(.tabGroupCollapse)
    }
    
    func expandFirstTabGroup() {
        openFirstTabGroupMenu()
        waitForMenuToBeDisplayed()
        clickTabGroupMenu(.tabGroupExpand)
    }
    
    func closeFirstTabGroup() {
        openFirstTabGroupMenu()
        waitForMenuToBeDisplayed()
        clickTabGroupMenu(.tabGroupCloseGroup)
    }
    
    func captureFirstTabGroup() {
        openFirstTabGroupMenu()
        waitForMenuToBeDisplayed()
        clickTabGroupMenu(.tabGroupCapture)
        typeKeyboardKey(.enter)
        typeKeyboardKey(.escape)
    }
    
}
