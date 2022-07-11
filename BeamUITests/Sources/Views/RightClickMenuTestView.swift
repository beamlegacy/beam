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
        app.windows.menuItems[item.accessibilityIdentifier].clickOnExistence()
    }
    
    func clickLinkMenu(_ item: RightClickMenuViewLocators.LinkMenuItems) {
        app.windows.menuItems[item.accessibilityIdentifier].clickOnExistence()
    }
    
    func clickTextMenu(_ item: RightClickMenuViewLocators.TextMenuItems) {
        app.windows.menuItems[item.accessibilityIdentifier].clickOnExistence()
    }
    
    func clickCommonMenu(_ item: RightClickMenuViewLocators.CommonMenuItems) {
        app.windows.menuItems[item.accessibilityIdentifier].clickOnExistence()
    }
    
    @discardableResult
    func waitForMenuToBeDisplayed() -> Bool {
        return app.menuItems[RightClickMenuViewLocators.CommonMenuItems.inspectElement.accessibilityIdentifier].waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    @discardableResult
    func waitForShareMenuToBeDisplayed() -> Bool {
        return app.menuItems[RightClickMenuViewLocators.ShareCommonMenuItems.shareByMail.accessibilityIdentifier].waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    @discardableResult
    func waitForSpeechMenuToBeDisplayed() -> Bool {
        return app.menuItems[RightClickMenuViewLocators.SpeechCommonMenuItems.startSpeaking.accessibilityIdentifier].waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    @discardableResult
    func waitForServiceMenuToBeDisplayed() -> Bool {
        return app.menuItems[RightClickMenuViewLocators.ServicesMenuItems.serviceShowInfoInFinder.accessibilityIdentifier].waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    func isSpeechMenuDisplayed() -> Bool {
        waitForSpeechMenuToBeDisplayed()
        return app.windows.menuItems[RightClickMenuViewLocators.SpeechCommonMenuItems.startSpeaking.accessibilityIdentifier].isEnabled && !app.windows.menuItems[RightClickMenuViewLocators.SpeechCommonMenuItems.stopSpeaking.accessibilityIdentifier].isEnabled
    }
    
    func isShareCommonMenuDisplayed() -> Bool {
        waitForShareMenuToBeDisplayed()
        var result = true
        for item in RightClickMenuViewLocators.ShareCommonMenuItems.allCases {
            result = result && app.windows.menuItems[item.accessibilityIdentifier].isEnabled
        }
        return result
    }
    
    func isServiceMenuDisplayed() -> Bool {
        waitForServiceMenuToBeDisplayed()
        var result = true
        for item in RightClickMenuViewLocators.ServicesMenuItems.allCases {
            result = result && app.windows.menuItems[item.accessibilityIdentifier].isEnabled
        }
        return result
    }
    
}
