//
//  AdBlockerTestView.swift
//  BeamUITests
//
//  Created by Quentin Valero on 10/05/2022.
//

import Foundation
import XCTest

class AdBlockerTestView: BaseView {
    
    func allowWebSiteOnce() -> WebTestView {
        button(AdBlockerViewLocators.Buttons.justThisTimeButton.accessibilityIdentifier).clickOnExistence()
        return WebTestView()
    }
    
    func allowWebSitePermanently() -> WebTestView {
        button(AdBlockerViewLocators.Buttons.permanentlyButton.accessibilityIdentifier).clickOnExistence()
        return WebTestView()
    }
    
    func isWebsiteBlocked() -> Bool {
        return staticText(AdBlockerViewLocators.StaticTexts.siteBlockedByBeamText.accessibilityIdentifier).exists
    }
    
    func getBlockedUrlElement() -> XCUIElement {
        XCTContext.runActivity(named: "Return host blocked by AdBlocker") {_ in
            let predicate = NSPredicate(format: "value BEGINSWITH 'The site '")
            let hostBlockedMessage = app.staticTexts.matching(predicate).firstMatch
            return hostBlockedMessage
        }
    }
    
    func getBlockedHostElement() -> XCUIElement {
        XCTContext.runActivity(named: "Return host blocked by AdBlocker") {_ in
            let predicate = NSPredicate(format: "value BEGINSWITH 'Disable blocking for '")
            let hostBlockedMessage = app.staticTexts.matching(predicate).firstMatch
            return hostBlockedMessage
        }
    }
}
