//
//  ContextMenuTestView.swift
//  BeamUITests
//
//  Created by Remi Santos on 24/09/2021.
//

import Foundation
import XCTest

class ContextMenuTestView: BaseView {

    private var key: String
    init(key: String) {
        self.key = key
        super.init()
    }

    func menuElement() -> XCUIElement {
        app.groups[key]
    }

    override func staticText(_ element: String) -> XCUIElement {
        self.menuElement().staticTexts[element]
    }
    
    @discardableResult
    func clickSlashMenuItem(item: NoteViewLocators.SlashContextMenuItems) -> BaseView {
        staticText(item.accessibilityIdentifier).clickOnExistence()
        return BaseView()
    }

    @discardableResult
    func clickItem(item: NoteViewLocators.ContextMenuItems) -> BaseView {
        staticText(item.accessibilityIdentifier).clickOnExistence()
        return BaseView()
    }
    
}
