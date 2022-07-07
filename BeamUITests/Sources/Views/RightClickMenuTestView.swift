//
//  RightClickMenuTestView.swift
//  BeamUITests
//
//  Created by Quentin Valero on 07/07/2022.
//

import Foundation
import XCTest

class RightClickMenuTestView: BaseView {
    
    func clickMenu(_ item: RightClickMenuViewLocators.MenuItems) {
        app.menuItems[item.accessibilityIdentifier].clickOnExistence()
    }
    
    @discardableResult
    func waitForMenuToBeDisplayed() -> Bool {
        return app.menuItems[RightClickMenuViewLocators.MenuItems.inspectElement.accessibilityIdentifier].waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    @discardableResult
    func waitForShareMenuToBeDisplayed() -> Bool {
        return app.menuItems[RightClickMenuViewLocators.ShareMenuItems.shareByMail.accessibilityIdentifier].waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
}
