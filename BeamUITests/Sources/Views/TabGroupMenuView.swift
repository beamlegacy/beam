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
    func openFirstTabGroupMenu() -> TabGroupMenuView {
        getFirstTabGroup().rightClickInTheMiddle()
        return self
    }
    
    @discardableResult
    func waitForMenuToBeDisplayed() -> Bool {
        return textField(TabGroupMenuViewLocators.MenuItems.tabGroupName.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout)
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
    
}
