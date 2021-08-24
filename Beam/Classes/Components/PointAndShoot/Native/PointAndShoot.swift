import Foundation
import BeamCore
import SwiftSoup
import Promises

struct PointAndShootError: LocalizedError {
    var errorDescription: String?
    var failureReason: String?
    var recoverySuggestion: String?
    var helpAnchor: String?

    init(_ desc: String, reason: String? = nil, suggestion: String? = nil, help: String? = nil) {
        errorDescription = desc
        failureReason = reason
        recoverySuggestion = suggestion
        helpAnchor = help
    }
}

public struct NoteInfo: Encodable {
    var id: UUID = UUID()
    let title: String
}

// swiftlint:disable file_length
class PointAndShoot: WebPageHolder, ObservableObject {
    var webPositions: WebPositions = WebPositions()
    var data: BeamData = AppDelegate.main.data
    private let scorer: BrowsingScorer
    @Published var activePointGroup: ShootGroup?
    @Published var activeSelectGroup: ShootGroup?
    @Published var activeShootGroup: ShootGroup?
    @Published var collectedGroups: [ShootGroup] = []
    @Published var dismissedGroups: [ShootGroup] = [] {
        didSet {
            // Stop watching the groups that are dismissed
            dismissedGroups.forEach({ group in
                removeTarget(group.id)
            })
        }
    }
    @Published var shootConfirmationGroup: ShootGroup?
    @Published var isAltKeyDown: Bool = false
    @Published var hasActiveSelection: Bool = false
    @Published var isTypingOnWebView: Bool = false
    @Published var mouseLocation: NSPoint = NSPoint()

    init(scorer: BrowsingScorer) {
        self.scorer = scorer
    }

    override var page: WebPage {
        get {
            super.page
        }
        set {
            super.page = newValue
            self.page.webView.optionKeyToggle = { key in
                self.refresh(self.mouseLocation, key)
            }
            self.page.webView.mouseClickChange = { (mousePos) in
                self.handleMouseClick(mousePos)
            }
            self.page.webView.mouseMoveTriggeredChange = { (mousePos, modifier) in
                self.refresh(mousePos, modifier)
            }
        }
    }

    /// If activeShootGorup and click location overlap, cancel active shoot
    /// - Parameter mousePos: Point of mousePosition
    func handleMouseClick(_ mousePos: NSPoint) {
        if let group = self.activeShootGroup {
            for target in group.targets {
                if !hasGraceRectAndMouseOverlap(target, group.href, mousePos) {
                    cancelShoot()
                }
            }
        }
    }

    /// Refreshes the mouseLocation, isAltKeyDown variables with updated values. If key modifier contains option
    /// and there's an active selection + selectgroup we shoot the select group.
    /// - Parameters:
    ///   - mousePos: Point of mousePosition
    ///   - modifier: Array of modifier keys used in event
    func refresh(_ mousePos: NSPoint, _ modifier: NSEvent.ModifierFlags) {
        self.mouseLocation = mousePos
        isAltKeyDown = modifier.contains(.option)

        // refresh event contains option key, and we have a active selection + activeSelectGroup
        if modifier.contains(.option),
           let group = self.activeSelectGroup,
           hasActiveSelection {
            // shoot the selection
            self.selectShoot(group)
            // Clear the activeSelectGroup
            activeSelectGroup = nil
        }
    }

    /**
     * A group of blocks that can be associated to a Note as a whole and at once.
     */
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
        var isText: Bool = true
        func html() -> String {
            targets.reduce("", {
                $1.html.count > $0.count ? $1.html : $0
            })
        }
        private(set) var groupPath: CGPath = CGPath(rect: .zero, transform: nil)
        private(set) var groupRect: CGRect = .zero
        private let groupPadding: CGFloat = 4
        private let groupRadius: CGFloat = 4
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
                  var lastTarget = targets.last else {
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

    /// Describes a target area as part of a Shoot group
    struct Target {
        /// ID of the target
        var id: String
        /// Rectangle Area of the target
        var rect: NSRect
        /// Point location of the mouse. It's used to draw the ShootCardPicker location.
        /// It's `x` and `y` location is relative to the top left corner of the area
        var mouseLocation: NSPoint
        /// HTML string of the targeted element
        var html: String
        /// Decides if ui applies animations
        var animated: Bool
        /// Translates target for scaling and positioning of frame
        func translateTarget(_ xDelta: CGFloat = 0, _ yDelta: CGFloat = 0, scale: CGFloat) -> Target {
            let newRect = NSRect(
                x: (rect.minX + xDelta) * scale,
                y: (rect.minY + yDelta) * scale,
                width: rect.width * scale,
                height: rect.height * scale
            )
            let newLocation = NSPoint(
                x: (mouseLocation.x + xDelta) * scale,
                y: (mouseLocation.y + yDelta) * scale
            )
            return Target(id: id, rect: newRect, mouseLocation: newLocation, html: html, animated: animated)
        }
    }

    /// Creates initial Point and Shoot target
    /// - Parameters:
    ///   - rect: area of target to be drawn
    ///   - id: id of html element
    ///   - href: url location of target
    /// - Returns: Translated target
    func createTarget(_ id: String, _ rect: NSRect, _ html: String, _ href: String, _ animated: Bool) -> Target {
        return Target(
            id: id,
            rect: rect,
            mouseLocation: mouseLocation.clamp(rect),
            html: html,
            animated: animated
        )
    }

    func translateAndScaleTarget(_ target: PointAndShoot.Target, _ href: String) -> PointAndShoot.Target {
        guard let view = page.webView else {
            fatalError("Webview is required to scale target correctly")
        }
        let scale: CGFloat = webPositions.scale * view.zoomLevel()
        // We can reduce calculations for the MainWindowFrame
        guard href != page.url?.absoluteString else {
            // We can futher reduce calculations if the scale is 1
            guard scale != 1 else {
                return target
            }
            return target.translateTarget(0, 0, scale: scale)
        }

        let frameOffsetX = webPositions.viewportPosition(href, prop: WebPositions.FramePosition.x).reduce(0, +)
        let frameOffsetY = webPositions.viewportPosition(href, prop: WebPositions.FramePosition.y).reduce(0, +)
        let frameScrollX = webPositions.viewportPosition(href, prop: WebPositions.FramePosition.scrollX)
        let frameScrollY = webPositions.viewportPosition(href, prop: WebPositions.FramePosition.scrollY)
        let xDelta = frameOffsetX - frameScrollX.reduce(0, +)
        let yDelta = frameOffsetY - frameScrollY.reduce(0, +)

        return target.translateTarget(xDelta, yDelta, scale: scale)
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

    /// Set activePointGroup with target. Updating the activePointGroup will update the UI directly.
    func point(_ target: Target, _ href: String) {
        guard activeShootGroup == nil else { return }
        guard !isTypingOnWebView else { return }

        activePointGroup = ShootGroup("point-uuid", [target], href)
    }

    /// Set targets as activeShootGroup
    /// - Parameters:
    ///   - groupId: id of group
    ///   - targets: Set of targets to draw
    ///   - href: Url of frame targets are located in
    func pointShoot(_ groupId: String, _ target: Target, _ href: String) {
        guard !targetIsDismissed(groupId), !hasActiveSelection else { return }

        if targetIsCollected(groupId) {
            collect(groupId, [target], href)
            return
        }

        if (isAltKeyDown || activeShootGroup != nil), activePointGroup != nil {
            // if we have an existing group matching the id
            if activeShootGroup != nil, activeShootGroup?.id == groupId {
                activeShootGroup?.updateTargets(groupId, [target])
            } else if hasGraceRectAndMouseOverlap(target, href, mouseLocation),
                      !isLargeTargetArea(target),
                      !isTypingOnWebView,
                      activeSelectGroup == nil {

                activeShootGroup = ShootGroup(groupId, [target], href)
            } else {
                if !isAltKeyDown {
                    let tempGroup = ShootGroup(groupId, [], href)
                    dismissedGroups.append(tempGroup)
                }
            }
        }
    }

    /// Draw function for selection. `activeSelectGroup` is used as a storage variable until option is pressed.
    /// Assigning the selection targets to the `activeShootGroup` happens in `refresh()`.
    /// - Parameters:
    ///   - groupId: id of group, for selections this is the non-number version. Targets have the same `id + index`
    ///   - targets: Target rects to draw
    ///   - href: href of frame
    func select(_ groupId: String, _ targets: [Target], _ href: String) {
        guard !isTypingOnWebView else {
            return
        }
        // Check if the incomming group is already collected
        if targetIsCollected(groupId) {
            collect(groupId, targets, href)
            return
        }
        // Check if the target was previously dismissed
        if targetIsDismissed(groupId) {
            return
        }

        if activeShootGroup != nil, activeShootGroup?.id == groupId {
            // if we have an existing group matching the id
            activeShootGroup?.updateTargets(groupId, targets)
            return
        }

        if activeSelectGroup?.id == groupId {
            // Update selection group
            activeSelectGroup?.updateTargets(groupId, targets)
            return
        } else if hasActiveSelection, activeSelectGroup == nil {
            // Create a new Selection group
            activeSelectGroup = ShootGroup(groupId, targets, href)
            return
        }
    }

    /// When selection collapses, check if selection is used, otherwise remove it from tracked Elements
    /// - Parameter id: id of group to clear
    func clearSelection(_ id: String) {
        if activeSelectGroup?.id == id,
           activeShootGroup?.id == id,
           targetIsCollected(id),
           targetIsDismissed(id) {
            return
        }

        if let selectionGroup = activeSelectGroup, activeSelectGroup?.id == id {
            dismissedGroups.append(selectionGroup)
            activeSelectGroup = nil
        }
    }

    /// Sets selection group as activeShootGroup
    /// - Parameters:
    ///   - group: Group to be converted
    func selectShoot(_ group: ShootGroup) {
        guard !targetIsDismissed(group.id) else {
            return
        }

        if targetIsCollected(group.id) {
            collect(group.id, group.targets, group.href)
            return
        }
        guard !isTypingOnWebView else { return }
        activeShootGroup = group
    }

    /// Set or update targets to collectedGroup
    /// - Parameters:
    ///   - groupId: id of group to update
    ///   - targets: Set of targets to draw
    ///   - href: Url of frame targets are located in
    func collect(_ groupId: String, _ targets: [Target], _ href: String) {
        guard targets.count > 0 else { return }
        guard !isTypingOnWebView else { return }

        // Keep shootConfirmationGroup position when scrolling
        if shootConfirmationGroup != nil {
            shootConfirmationGroup?.updateTargets(groupId, targets)
        }

        if let index = collectedGroups.firstIndex(where: {$0.id == groupId}) {
            var existingGroup = collectedGroups[index]
            existingGroup.updateTargets(groupId, targets)
            collectedGroups[index] = existingGroup
        } else {
            let newGroup = ShootGroup(groupId, targets, href)
            collectedGroups.append(newGroup)
        }
    }

    /// Draws shoot confirmation
    /// - Parameter group: ShootGroup of targets to draw the confirmation UI
    private func showShootInfo(group: ShootGroup) {
        shootConfirmationGroup = group
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            self.shootConfirmationGroup = nil
        }
    }

    /// Small Utility to create a BeamElement containing noteText
    /// - Parameter noteText: Text of note
    /// - Returns: BeamElement containing noteText without any styling
    fileprivate func createNote(_ noteText: String) -> BeamElement {
        let note = BeamElement(BeamText(text: noteText))
        note.query = self.page.originalQuery
        return note
    }

    /// Adds the activeShootGroup to the journal. It will convert the html to beamtext, apply quote styling and download any target images.
    /// - Parameters:
    ///   - noteTitle: title of note to assign to.
    ///   - noteText: optional text to add underneath the shoot quote
    func addShootToNote(noteTitle: String, withNote noteText: String? = nil, group: ShootGroup) {
        guard let sourceUrl = page.url,
              let currentNote = page.getNote(fromTitle: noteTitle) else {
            fatalError("Could not find note to update with title \(noteTitle)")
        }
        // Make group mutable
        var shootGroup = group
        // Set Destination note to the current card
        // Update BrowsingScorer about note submission
        page.setDestinationNote(currentNote, rootElement: currentNote)
        scorer.addTextSelection()
        // Convert html to BeamText
        let texts: [BeamText] = html2Text(url: sourceUrl, html: shootGroup.html())
        // Reduce array of texts to a single string
        let clusteringText = texts.reduce(String()) { (string, beamText) -> String in
            string + " " + beamText.text
        }
        // Send this string to the ClusteringManager
        self.page.addTextToClusteringManager(clusteringText, url: sourceUrl)
        // Convert BeamText to BeamElement of quote type
        let pendingQuotes = text2Quote(texts, sourceUrl.absoluteString)
        // Adds urlId to current card source
        let urlId = LinkStore.createIdFor(sourceUrl.absoluteString, title: nil)
        currentNote.sources.add(urlId: urlId, noteId: currentNote.id, type: .user, sessionId: data.sessionId, activeSources: data.activeSources)
        // Updates frecency score of destination note
        data.noteFrecencyScorer.update(id: currentNote.id, value: 1.0, eventType: .notePointAndShoot, date: BeamDate.now, paramKey: .note30d0)
        // Add all quotes to source Note
        if let source = self.page.addToNote(allowSearchResult: true) {
            pendingQuotes.then({ resolvedQuotes in
                var quotes = resolvedQuotes
                if let noteText = noteText, !noteText.isEmpty,
                   let lastQuote = quotes.popLast() {
                    // Append NoteText last quote
                    let note = self.createNote(noteText)
                    lastQuote.addChild(note)
                    quotes.append(lastQuote)
                }
                // Add to source Note
                quotes.forEach({ quote in
                    if quote.imageLink != nil {
                        shootGroup.isText = false
                    }
                    source.addChild(quote)
                })
                // Complete PNS and clear stored data
                shootGroup.setNoteInfo(NoteInfo(id: currentNote.id, title: currentNote.title))
                shootGroup.numberOfElements = resolvedQuotes.count
                self.collectedGroups.append(shootGroup)
                self.showShootInfo(group: shootGroup)
                self.activeShootGroup = nil
            })
        }
    }

    /// Clears all stored Point and Shoot session data
    func leavePage() {
        activePointGroup = nil
        activeSelectGroup = nil
        activeShootGroup = nil
        collectedGroups.removeAll()
        dismissedGroups.removeAll()
        shootConfirmationGroup = nil
        isAltKeyDown = false
        hasActiveSelection = false
    }

    func cancelShoot() {
        if let group = activeShootGroup {
            dismissedGroups.append(group)
            activeShootGroup = nil
        }
        if let group = activeSelectGroup {
            dismissedGroups.append(group)
            activeSelectGroup = nil
        }
    }

    /// Stop JS from sending updated bounds of target element
    ///
    /// Calling this is a performance improvement for the main window
    /// frame context only, we can't rely this gets properly executed within iframes.
    /// - Parameter id: ID of target to remove
    func removeTarget(_ id: String) {
        self.page.executeJS("removeTarget(\"\(id)\")", objectName: "PointAndShoot")
    }
}
