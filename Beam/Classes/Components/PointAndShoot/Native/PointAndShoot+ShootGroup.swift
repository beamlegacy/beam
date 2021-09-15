//
//  PointAndShoot+ShootGroup.swift
//  Beam
//
//  Created by Stef Kors on 30/08/2021.
//

import Foundation

extension PointAndShoot {
    /// A group of blocks that can be associated to a Note as a whole and at once.
    enum ShootConfirmation: String {
        case success
        case failure
    }

    struct ShootGroup {
        init(_ id: String, _ targets: [Target], _ href: String, _ noteInfo: NoteInfo = NoteInfo(title: "")) {
            self.id = id
            self.href = href
            self.targets = targets
            self.noteInfo = noteInfo
            self.updateSelectionPath()
        }

        let href: String
        var id: String
        var targets: [Target] = []
        var noteInfo: NoteInfo
        var numberOfElements: Int = 0
        var confirmation: ShootConfirmation?
        func html() -> String {
            targets.reduce("", {
                $1.html.count > $0.count ? $1.html : $0
            })
        }
        private(set) var groupPath: CGPath = CGPath(rect: .zero, transform: nil)
        private(set) var groupRect: CGRect = .zero
        private let groupPadding: CGFloat = 4
        private let groupRadius: CGFloat = 4
        mutating func setConfirmation(_ state: ShootConfirmation) {
            confirmation = state
        }
        mutating func setNoteInfo(_ note: NoteInfo) {
            noteInfo = note
        }
        mutating func updateSelectionPath() {
            let fusionRect = ShootFrameFusionRect().getRect(targets: targets).insetBy(dx: -groupPadding, dy: -groupPadding)
            groupRect = fusionRect
            if targets.count > 1 {
                let allRects = targets.map { $0.rect.insetBy(dx: -groupPadding, dy: -groupPadding) }
                groupPath = CGPath.makeUnion(of: allRects, cornerRadius: groupRadius)
            } else {
                groupPath = CGPath(roundedRect: fusionRect, cornerWidth: groupRadius, cornerHeight: groupRadius, transform: nil)
            }
        }
        /// If target exists update the rect and translate the mouseLocation point.
        /// - Parameter newTarget: Target containing new rect
        mutating func updateTarget(_ newTarget: Target) {
            // find the matching targets and update Rect and MouseLocation
            if let index = targets.firstIndex(where: { $0.id == newTarget.id }) {
                let diffX = targets[index].rect.minX - newTarget.rect.minX
                let diffY = targets[index].rect.minY - newTarget.rect.minY
                let oldPoint = targets[index].mouseLocation
                targets[index].rect = newTarget.rect
                targets[index].mouseLocation = NSPoint(x: oldPoint.x - diffX, y: oldPoint.y - diffY)
                updateSelectionPath()
            }
        }

        mutating func updateTargets(_ groupId: String, _ newTargets: [Target]) {
            guard id == groupId,
                  var lastTarget = targets.last,
                  !newTargets.isEmpty else {
                return
            }

            // Take the last of the newTargets and current targets
            // Use those to calculate and set the rect and mouselocation of the lastNewTarget
            // Set the value of newTargets as the current targets inlcuding the computed one
            var mutableNewTargets = newTargets
            let lastNewTarget = mutableNewTargets.removeLast()
            let diffX = lastTarget.rect.minX - lastNewTarget.rect.minX
            let diffY = lastTarget.rect.minY - lastNewTarget.rect.minY
            let oldPoint = lastTarget.mouseLocation
            lastTarget.rect = lastNewTarget.rect
            lastTarget.mouseLocation = NSPoint(x: oldPoint.x - diffX, y: oldPoint.y - diffY)
            mutableNewTargets.append(lastTarget)
            targets = mutableNewTargets
            updateSelectionPath()
        }
    }
    func translateAndScaleGroup(_ group: PointAndShoot.ShootGroup) -> PointAndShoot.ShootGroup {
        var newGroup = group
        let href = group.href
        let newTargets = newGroup.targets.map({ target in
            return translateAndScaleTarget(target, href)
        })
        newGroup.updateTargets(newGroup.id, newTargets)
        return newGroup
    }

    func convertTargetToCircleShootGroup(_ target: Target, _ href: String) -> ShootGroup {
        let size: CGFloat = 20
        let circleRect = NSRect(x: mouseLocation.x - (size / 2), y: mouseLocation.y - (size / 2), width: size, height: size)
        var circleTarget = target
        circleTarget.rect = circleRect
        return ShootGroup("point-uuid", [circleTarget], href)
    }
}
