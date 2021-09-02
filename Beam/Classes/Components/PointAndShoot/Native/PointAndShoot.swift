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
                    source.addChild(quote)
                })
                // Complete PNS and clear stored data
                shootGroup.numberOfElements = resolvedQuotes.count
            }).catch({ error in
                self.showAlert(shootGroup, texts, error.localizedDescription)
            }).always {
                if shootGroup.numberOfElements != texts.count || shootGroup.numberOfElements == 0 {
                    self.showAlert(shootGroup, texts, "numberOfElements and texts.count mismatch")
                }
                shootGroup.setNoteInfo(NoteInfo(id: currentNote.id, title: currentNote.title))
                self.collectedGroups.append(shootGroup)
                self.showShootInfo(group: shootGroup)
                self.activeShootGroup = nil
            }
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
