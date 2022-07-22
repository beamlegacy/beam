//
//  BeamNote+CommandManager.swift
//  Beam
//
//  Created by Sebastien Metrot on 01/04/2021.
//

import Foundation
import BeamCore

public extension BeamNote {
    private static var commandManagers: [UUID: CommandManager<Widget>] = [:]
    
    var cmdManager: CommandManager<Widget> {
        if let manager = Self.commandManagers[self.id] {
            return manager
        }

        let manager = CommandManager<Widget>()
        Self.commandManagers[self.id] = manager
        return manager
    }

    func resetCommandManager() {
        Self.commandManagers.removeValue(forKey: self.id)
    }
}
