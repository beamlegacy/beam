//
//  GoMenu.swift
//  BeamUITests
//
//  Created by Andrii on 10.08.2021.
//

import Foundation
import XCTest

class GoMenu: BaseMenuBar {
    
    let menuBarTitle = "Go"
    
    func changeCard() {
        menuBarItem(menuBarTitle).click()
        menuItem("Change Note").click()
    }
    
}
