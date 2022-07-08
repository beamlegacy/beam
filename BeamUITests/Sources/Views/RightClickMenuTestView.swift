//
//  RightClickMenuTestView.swift
//  BeamUITests
//
//  Created by Quentin Valero on 07/07/2022.
//

import Foundation
import XCTest

class RightClickMenuTestView: BaseView {
    
    func clickImageMenu(_ item: RightClickMenuViewLocators.ImageMenuItems) {
        app.menuItems[item.accessibilityIdentifier].clickOnExistence()
    }
    
    func clickLinkMenu(_ item: RightClickMenuViewLocators.LinkMenuItems) {
        app.menuItems[item.accessibilityIdentifier].clickOnExistence()
    }
    
    func clickCommonMenu(_ item: RightClickMenuViewLocators.CommonMenuItems) {
        app.menuItems[item.accessibilityIdentifier].clickOnExistence()
    }
    
    @discardableResult
    func waitForMenuToBeDisplayed() -> Bool {
        return app.menuItems[RightClickMenuViewLocators.CommonMenuItems.inspectElement.accessibilityIdentifier].waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    @discardableResult
    func waitForShareMenuToBeDisplayed() -> Bool {
        return app.menuItems[RightClickMenuViewLocators.ShareCommonMenuItems.shareByMail.accessibilityIdentifier].waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
}
