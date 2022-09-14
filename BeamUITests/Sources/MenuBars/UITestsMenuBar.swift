//
//  UITestsMenuBar.swift
//  BeamUITests
//
//  Created by Andrii on 26.07.2021.
//

import Foundation
import XCTest

class UITestsMenuBar: BaseMenuBar {
    
    let beeper: CrossTargetBeeper = CrossTargetNotificationCenterBeeper()
    
    @discardableResult
    func invoke(_ command: UITestMenuAvailableCommands) -> UITestsMenuBar {
        beeper.beep(identifier: command.rawValue)
        return self
    }
    
}
