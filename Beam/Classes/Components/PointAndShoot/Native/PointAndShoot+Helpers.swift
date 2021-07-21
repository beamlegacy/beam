//
//  PointAndShoot+Helpers.swift
//  Beam
//
//  Created by Stef Kors on 16/07/2021.
//

import Foundation
import BeamCore
import Promises

extension PointAndShoot {
    /// Dismiss activeShootGroup. Group gets added to dismissedGroups array and activeShootGroup gets cleared.
    func dismissShoot() {
        if let group = activeShootGroup {
            dismissedGroups.append(group)
            activeShootGroup = nil
        }
    }

    /// Checks if group is previously collected
    /// - Parameter id: ID of group to check
    /// - Returns: True if group is in collectedGroups array
    func targetIsCollected(_ id: String) -> Bool {
        var bool = false
        for group in collectedGroups where group.id == id {
            bool = true
        }
        return bool
    }

    /// Checks if group is previously dismissed
    /// - Parameter id: ID of group to check
    /// - Returns: True if group is in dismissedGroups array
    func targetIsDismissed(_ id: String) -> Bool {
        var bool = false
        for group in dismissedGroups where group.id == id {
            bool = true
        }
        return bool
    }
}
