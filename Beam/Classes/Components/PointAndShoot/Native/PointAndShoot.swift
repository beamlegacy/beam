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

public enum PointAndShootStatus: String, CodingKey {
    case none
    case pointing
    case shooting
}

public struct NoteInfo: Encodable {
    let id: UUID?   // Should not be nilable once we get it
    let title: String
}

class PointAndShoot: WebPageHolder {
    var webPositions: WebPositions = WebPositions()

    var _status: PointAndShootStatus = .none
    var status: PointAndShootStatus {
        get {
            return _status
        }
        set {
            if newValue != _status {
                switch newValue {
                case .none:
                    if _status == .pointing {
                        hidePointing()
                        hideShoot()
                    }

                    if _status == .shooting {
                        hideShoot()
                    }

                case .shooting:
                    if _status == .pointing {
                        hidePointing()
                    }

                default: break
                }
                _status = newValue
                if Configuration.pnsStatus {
                    ui.swiftPointStatus = _status.rawValue
                }
            }

            draw()
        }
    }

    var isPointing: Bool {
        @inline(__always) get { status == .pointing }
    }

    private func hidePointing() {
        Logger.shared.logDebug("leavePointing()", category: .pointAndShoot)
        pointTarget = nil
    }

    private func hideShoot() {
        Logger.shared.logDebug("leaveShoot()", category: .pointAndShoot)
        ui.clearShoots()
        activeShootGroup = nil
    }

    func resetStatus() {
        executeJS("setStatus('none')")
    }

    private func executeJS(_ method: String) {
        page.executeJS(method, objectName: "PointAndShoot")
    }

    /**
     * A group of blocks that can be associated to a Note as a whole and at once.
     */
    class ShootGroup {

        let href: String

        init(href: String) {
            self.href = href
        }

        /**
         * The blocks that compose this group.
         */
        var targets: [Target] = []

        var quoteId: UUID?

        /**
         * The associated Note, if any.
         */
        var noteInfo: NoteInfo = NoteInfo(id: nil, title: "")

        func html() -> String {
            targets.reduce("", {
                $1.html.count > $0.count ? $1.html : $0
            })
        }
    }

    /// Describes a target area as part of a Shoot group
    struct Target {
        /// Rectangle Area of the target
        var area: NSRect
        /// Optional reference to the quoteId. This UUID references a quote in a BeamNote
        var quoteId: UUID?
        /// Point location of the mouse. It's used to draw the ShootCardPicker location.
        /// It's `x` and `y` location is relative to the top left corner of the area
        var mouseLocation: NSPoint
        // HTML string of the targeted element
        var html: String
        // Optional `x`, `y` coordinates for offsetting the quoteArea position toward the mouse cursor
        var offset: NSPoint?
        // Prefer using the parent class method
        func translateTarget(xDelta: CGFloat, yDelta: CGFloat, scale: CGFloat) -> Target {
            let newArea = NSRect(
                x: (area.minX + xDelta) * scale,
                y: (area.minY + yDelta) * scale,
                width: area.width * scale,
                height: area.height * scale
            )
            let newLocation = NSPoint(
                x: mouseLocation.x * scale,
                y: mouseLocation.y * scale
            )
            return Target(area: newArea, quoteId: quoteId, mouseLocation: newLocation, html: html, offset: offset)
        }
    }

    /// Translates a previously created target based on:
    /// - page horizontal scroll
    /// - page vertical scroll
    /// - page scaling
    /// Page scaling is calculated by multiplying the webView zoomLevel and the scaling received from JS.
    ///
    /// - Parameter target: The target to be translated
    /// - Parameter href: href of the frame containing the target
    /// - Returns: The translated target
    func translateTarget(target: Target, href: String) -> Target {
        let frameOffsetX = webPositions.viewportPosition(href, prop: WebPositions.FramePosition.x).reduce(0, +)
        let frameOffsetY = webPositions.viewportPosition(href, prop: WebPositions.FramePosition.y).reduce(0, +)
        let frameScrollX = webPositions.viewportPosition(href, prop: WebPositions.FramePosition.scrollX)
        let frameScrollY = webPositions.viewportPosition(href, prop: WebPositions.FramePosition.scrollY)
        let xDelta = frameOffsetX - frameScrollX.reduce(0, +)
        let yDelta = frameOffsetY - frameScrollY.reduce(0, +)
        guard let view = page.webView else {
            Logger.shared.logWarning("page webView required to translate target correctly", category: .pointAndShoot)
            return target.translateTarget(xDelta: xDelta, yDelta: yDelta, scale: webPositions.scale)
        }

        let scale = view.zoomLevel() * webPositions.scale
        return target.translateTarget(xDelta: xDelta, yDelta: yDelta, scale: scale)
    }

    /// Creates initial Point and Shoot target that takes into account page horizontal and vertical scroll and page scaling.
    /// Note: When creating a target we position it with scale set to `1`. We call `translateTarget()` before drawing the target which does use the current scaling value.
    /// - Parameters:
    ///   - area: The area coords.
    ///   - quoteId: ID of the stored quote. Defaults to `nil`.
    ///   - mouseLocation: Mouse location coords.
    ///   - html: The HTML content of the targeted element
    /// - Returns: Translated target
    func createTarget(area: NSRect, quoteId: UUID? = nil, mouseLocation: NSPoint, html: String, offset: NSPoint? = nil, href: String) -> Target {
        let target = Target(area: area, quoteId: quoteId, mouseLocation: mouseLocation, html: html, offset: offset)
        let xDelta = webPositions.viewportPosition(href, prop: WebPositions.FramePosition.scrollX).reduce(0, +)
        let yDelta = webPositions.viewportPosition(href, prop: WebPositions.FramePosition.scrollY).reduce(0, +)
        return target.translateTarget(xDelta: xDelta, yDelta: yDelta, scale: 1)
    }

    let ui: PointAndShootUI
    let scorer: BrowsingScorer

    init(ui: PointAndShootUI, scorer: BrowsingScorer) {
        self.ui = ui
        self.scorer = scorer
    }

    /**
     The pointing area (before shoot), if any.

     There is only one at a time.
     */
    var pointTarget: Target?

    /**
     The registered shoot sessions.

     Groups have associated ShootGroupUI managed by the PointAndShootUI
     */
    var shootGroups: [ShootGroup] = []

    /**
     The group being shot. It will added to groups once the card has been validated.
     */
    var activeShootGroup: ShootGroup?

    func point(target: Target, href: String) {
        pointTarget = translateTarget(target: target, href: href)
        ui.drawPoint(target: pointTarget!)
    }

    func cursor(target: Target, href: String) {
        pointTarget = translateTarget(target: target, href: href)
        ui.drawCursor(target: pointTarget!)
    }

    /// Removes PointFrame UI and resets the PNS status to .none, only runs when status is .pointing
    func unPoint() {
        if status == .pointing {
            resetStatus()
        }
    }

    func shoot(targets: [Target], href: String) {
        if activeShootGroup == nil {
            activeShootGroup = ShootGroup(href: href)
        }
        activeShootGroup?.targets = targets
    }

    /// update shootGroups with targets
    /// - Parameters:
    ///   - targets: the shoot targets to update
    ///   - href: browser tab href
    func updateShoots(targets: [Target], href: String) {
        let allGroups = [activeShootGroup] + shootGroups
        for group in allGroups.compactMap({ $0 }) {
            let newTargets = targets.filter { target in
                return group.quoteId == target.quoteId
            }

            if newTargets.count > 0 {
                group.targets = newTargets
            }
        }
    }

    func showShootInfo(group: ShootGroup) {
        let shootTarget = translateTarget(target: group.targets[0], href: group.href)
        ui.drawShootConfirmation(shootTarget: shootTarget, noteInfo: group.noteInfo)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            self.ui.clearConfirmation()
        }
    }

    func draw() {
        ui.clearShoots()
        switch status {
        case .pointing:
            drawAllGroups()
        case .shooting:
            ui.clearPoint()
            drawActiveShootGroup()
        case .none: break
        }
    }

    private func drawShootGroup(groups: [ShootGroup], edited: Bool) {
        for group in groups {
            let shootTargets = group.targets
            if shootTargets.count > 0 {
                var selectionUIs = [SelectionUI]()
                for shootTarget in shootTargets {
                    let target = translateTarget(target: shootTarget, href: group.href)
                    let selectionUI = ui.createUI(shootTarget: target)
                    selectionUIs.append(selectionUI)
                }
                _ = ui.createGroup(noteInfo: group.noteInfo, selectionUIs: selectionUIs, edited: edited)
            }
        }
    }

    private func drawAllGroups() {
        drawShootGroup(groups: shootGroups, edited: false)
    }

    private func drawActiveShootGroup() {
        guard let group = activeShootGroup else {
            Logger.shared.logInfo("Skipping drawCurrentGroup() currentGroup not defined", category: .pointAndShoot)
            return
        }
        drawShootGroup(groups: [group], edited: true)
    }

    /**
     Clear all remembered shoots
     */
    func removeAll() {
        shootGroups.removeAll()
        resetStatus()
    }

    /// Clears all remembered shoots and frameInfo
    func leavePage() {
        removeAll()
        webPositions.removeFrameInfo()
    }



    /// Small Utility to create a BeamElement containing noteText
    /// - Parameter noteText: Text of note
    /// - Returns: BeamElement containing noteText without any styling
    fileprivate func createNote(_ noteText: String) -> BeamElement {
        let note = BeamElement(BeamText(text: noteText))
        note.query = self.page.originalQuery
        return note
    }

    func addShootToNote(noteTitle: String, withNote noteText: String? = nil) {
        guard let sourceUrl = page.url,
              let currentCard = page.getNote(fromTitle: noteTitle) else {
            fatalError("Could not find note to update with title \(noteTitle)")
        }
        guard let shootGroup = activeShootGroup else {
            fatalError("Expected to have an active shoot group")
        }
        // Set Destination note to the current card
        // Update BrowsingScorer about note submission
        page.setDestinationNote(currentCard, rootElement: currentCard)
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
                    source.addChild(quote)
                })
                // Complete PNS and clear stored data
                let noteInfo = NoteInfo(id: currentCard.id, title: currentCard.title)
                self.complete(noteInfo: noteInfo, group: shootGroup)
            })
        }
    }

    func complete(noteInfo: NoteInfo, group: ShootGroup) {
        let quoteId = UUID()
        group.noteInfo = noteInfo
        shootGroups.append(group)
        executeJS("assignNote('\(quoteId)')")
        showShootInfo(group: group)
        activeShootGroup = nil
    }
}
