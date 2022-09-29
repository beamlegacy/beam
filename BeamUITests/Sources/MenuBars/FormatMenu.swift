//
//  FormatMenu.swift
//  BeamUITests
//
//  Created by Quentin Valero on 29/09/2022.
//

import Foundation
import XCTest

class FormatMenu: BaseMenuBar {
    
    let menuBarTitle = "Format"
    
    @discardableResult
    func invoke(_ command: Options) -> FormatMenu {
        menuBarItem(menuBarTitle).clickOnExistence()
        menuItem(command.rawValue).hoverAndTapInTheMiddle()
        return self
    }
    
    enum Options: String {
        case codeBlock = "Code Block"
    }
    
}
