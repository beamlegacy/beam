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
    func dismissActiveShootGroup() {
        if let group = activeShootGroup {
            dismissedGroups.append(group)
            activeShootGroup = nil
        }
    }

    /// Dismiss target shoot gorup. Group gets added to dismissedGroups array. Removes group from stored values if ids match target id
    /// - Parameter id: ID of group to remove
    /// - Parameter href: Href of the page
    func dismissShootGroup(id: String, href: String) {
        let group = ShootGroup(id: id, href: href)
        dismissedGroups.append(group)

        if activeShootGroup?.id == group.id {
            activeShootGroup = nil
        }

        if activeSelectGroup?.id == group.id {
            activeSelectGroup = nil
        }

        collectedGroups.removeAll(where: { collectedGroup in
            collectedGroup.id == group.id
        })
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
