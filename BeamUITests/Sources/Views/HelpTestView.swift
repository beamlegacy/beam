//
//  HelpTestView.swift
//  BeamUITests
//
//  Created by Andrii on 20.09.2021.
//

import Foundation
import XCTest

class HelpTestView: BaseView {
    
    func closeHelpView() {
        image(HelpViewLocators.Images.closeHelp.accessibilityIdentifier).clickOnExistence()
    }
    
    func openShortcuts() -> HelpTestView {
        staticText(HelpViewLocators.StaticTexts.shortcuts.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    func closeShortcuts() {
        button(HelpViewLocators.StaticTexts.closeShortcuts.accessibilityIdentifier).clickOnHittable()
    }
    
    @discardableResult
    func openBugReport() -> WebTestView {
        staticText(HelpViewLocators.StaticTexts.bug.accessibilityIdentifier).clickOnExistence()
        return WebTestView()
    }
    
    @discardableResult
    func openFeatureRequest() -> WebTestView {
        staticText(HelpViewLocators.StaticTexts.feature.accessibilityIdentifier).clickOnExistence()
        return WebTestView()
    }
    
    func getCmdLabel() -> XCUIElement {
        return image(HelpViewLocators.Images.cmdLabel.accessibilityIdentifier)
    }
    
    func getNumberOfCMDLabels() -> Int {
        return app.windows.images.matching(identifier: HelpViewLocators.Images.cmdLabel.accessibilityIdentifier).count
    }
}
