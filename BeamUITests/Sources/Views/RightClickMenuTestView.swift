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
        menuItem(item.accessibilityIdentifier).clickOnExistence()
    }
    
    func clickLinkMenu(_ item: RightClickMenuViewLocators.LinkMenuItems) {
        menuItem(item.accessibilityIdentifier).clickOnExistence()
    }
    
    func clickTextMenu(_ item: RightClickMenuViewLocators.TextMenuItems) {
        menuItem(item.accessibilityIdentifier).clickOnExistence()
    }
    
    func clickCommonMenu(_ item: RightClickMenuViewLocators.CommonMenuItems) {
        menuItem(item.accessibilityIdentifier).clickOnExistence()
    }
    
    @discardableResult
    func waitForMenuToBeDisplayed() -> Bool {
        return menuItem(RightClickMenuViewLocators.CommonMenuItems.inspectElement.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    @discardableResult
    func waitForShareMenuToBeDisplayed() -> Bool {
        return menuItem(RightClickMenuViewLocators.ShareCommonMenuItems.shareByMail.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    @discardableResult
    func waitForSpeechMenuToBeDisplayed() -> Bool {
        return menuItem(RightClickMenuViewLocators.SpeechCommonMenuItems.startSpeaking.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    @discardableResult
    func waitForServiceMenuToBeDisplayed() -> Bool {
        return menuItem(RightClickMenuViewLocators.ServicesMenuItems.serviceShowInfoInFinder.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    func isSpeechMenuDisplayed() -> Bool {
        waitForSpeechMenuToBeDisplayed()
        return menuItem(RightClickMenuViewLocators.SpeechCommonMenuItems.startSpeaking.accessibilityIdentifier).isEnabled && !menuItem(RightClickMenuViewLocators.SpeechCommonMenuItems.stopSpeaking.accessibilityIdentifier).isEnabled
    }
    
    func isShareCommonMenuDisplayed() -> Bool {
        waitForShareMenuToBeDisplayed()
        var result = true
        for item in RightClickMenuViewLocators.ShareCommonMenuItems.allCases {
            result = result && menuItem(item.accessibilityIdentifier).isEnabled
        }
        return result
    }
    
    func isServiceMenuDisplayed() -> Bool {
        waitForServiceMenuToBeDisplayed()
        var result = true
        for item in RightClickMenuViewLocators.ServicesMenuItems.allCases {
            result = result && menuItem(item.accessibilityIdentifier).isEnabled
        }
        return result
    }
    
}
