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
        init(_ id: String, _ targets: [Target], _ text: String, _ href: String,
             _ noteInfo: NoteInfo = NoteInfo(title: ""), shapeCache: PnSTargetsShapeCache?, showRect: Bool = true, directShoot: Bool = false) {
            self.id = id
            self.href = href
            self.targets = targets
            self.text = text
            self.noteInfo = noteInfo
            self.showRect = showRect
            self.directShoot = directShoot
            self.shapeCache = shapeCache
            self.updateSelectionPath()
        }

        let href: String
        var id: String
        var targets: [Target] = []
        var noteInfo: NoteInfo
        var shapeCache: PnSTargetsShapeCache?
        var numberOfElements: Int = 0
        var confirmation: ShootConfirmation?
        var showRect: Bool
        var directShoot: Bool
        func html() -> String {
            targets.reduce("", {
                $1.html.count > $0.count ? $1.html : $0
            })
        }
        /// Plain text string of the targeted content
        var text: String
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
            let fusionRect = self.getFusionRect(for: targets).insetBy(dx: -groupPadding, dy: -groupPadding)
            groupRect = fusionRect
            if let cachedShape = shapeCache?.getCachedShape(for: targets, fusionRect: fusionRect) {
                groupPath = cachedShape
                return
            }
            if targets.count > 1 && targets.count < 1000 {
                let allRects = targets.map { $0.rect.insetBy(dx: -groupPadding, dy: -groupPadding) }
                // medium size selection, let's calculate a complexe shape combining the rects
                groupPath = CGPath.makeUnion(of: allRects, cornerRadius: groupRadius)
            } else {
                // huge selection or single element, let's encapsulate everything in a simple rectangle
                groupPath = CGPath(roundedRect: fusionRect, cornerWidth: groupRadius, cornerHeight: groupRadius, transform: nil)
            }
            shapeCache?.setCachedShape(groupPath, for: targets, fusionRect: fusionRect)
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

        mutating func updateTargets(_ groupId: String, _ newTargets: [Target], updatePath: Bool = true) {
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
            if updatePath {
                updateSelectionPath()
            }
        }

        /// Caching the union rects of large target groups for performance. Using the first rect to compare the different offset.
        private var largefusionRectsCache: [NSString: (firstRect: CGRect, fusionRect: CGRect)] = [:]
        private mutating func getFusionRect(for targets: [Target]) -> CGRect {
            let initialRect: CGRect = targets.first?.rect ?? .zero
            let shouldUseCache = targets.count > 10
            var cacheKey: NSString?
            if shouldUseCache, let shapeCache = shapeCache {
                let key = shapeCache.cacheKey(for: targets)
                if let cachedRect = largefusionRectsCache[key] {
                    let diffX = cachedRect.firstRect.minX - initialRect.minX
                    let diffY = cachedRect.firstRect.minY - initialRect.minY
                    var fusionRect = cachedRect.fusionRect
                    fusionRect.origin.x -= diffX
                    fusionRect.origin.y -= diffY
                    return fusionRect
                }
                cacheKey = key
            }
            let fusionRect = targets.reduce(initialRect) { $0.union($1.rect) }
            if let cacheKey = cacheKey {
                largefusionRectsCache[cacheKey] = (firstRect: initialRect, fusionRect: fusionRect)
            }
            return fusionRect
        }
    }

    func translateAndScaleGroup(_ group: PointAndShoot.ShootGroup) -> PointAndShoot.ShootGroup {
        let href = group.href
        if let newTargets: [Target] = translateAndScaleTargetsIfNeeded(group.targets, href) {
            var newGroup = group
            newGroup.updateTargets(newGroup.id, newTargets)
            return newGroup
        }
        return group
    }

    func convertTargetToCircleShootGroup(_ target: Target, _ href: String) -> ShootGroup {
        let size: CGFloat = 20
        let circleRect = NSRect(x: mouseLocation.x - (size / 2), y: mouseLocation.y - (size / 2), width: size, height: size)
        var circleTarget = target
        circleTarget.rect = circleRect
        return ShootGroup("point-uuid", [circleTarget], "", href, shapeCache: shapeCache)
    }
}

extension PointAndShoot {
    /**
     A cache for the CGPath calculated for a ShootGroup

     Cache key is a string from `numberOfTargets` + `id of first target` + `id of last target`
     This should be deterministic enough to assume that a shape between these two targets should be the same

     We use this cache because the shape might be the same, but depending on the scroll position, the origin of the shape could differ.
     For this case instead of creating a whole new shape, we will simply translate the cached shape.
     That's why we store the cached shape translated to a zero origin.
     */
    class PnSTargetsShapeCache {
        private var cache = NSCache<NSString, CGPath>()

        fileprivate func cacheKey(for targets: [Target]) -> NSString {
            var targetsToUse: [Target] = []
            if targets.count >= 2 {
                if let first = targets.first, let last = targets.last {
                    targetsToUse.append(first)
                    targetsToUse.append(last)
                }
            } else {
                targetsToUse = targets
            }
            let listOfTargetIds = targetsToUse.map { $0.id }.joined(separator: "-to-")
            return NSString(string: "\(targets.count)t-" + listOfTargetIds)
        }

        func getCachedShape(for targets: [Target], fusionRect: CGRect) -> CGPath? {
            let key = cacheKey(for: targets)
            guard let path = cache.object(forKey: key) else { return nil }
            var transform = CGAffineTransform(translationX: fusionRect.minX, y: fusionRect.minY)
            let shiftedShape = path.copy(using: &transform)
            return shiftedShape
        }

        func setCachedShape(_ shape: CGPath, for targets: [Target], fusionRect: CGRect) {
            let key = cacheKey(for: targets)
            var transform = CGAffineTransform(translationX: -fusionRect.minX, y: -fusionRect.minY)
            let shiftedShape = shape.copy(using: &transform) ?? shape
            cache.setObject(shiftedShape, forKey: key)
        }

        func clear() {
            cache.removeAllObjects()
        }
    }
}
