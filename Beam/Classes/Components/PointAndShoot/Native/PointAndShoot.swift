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
    var data: BeamData = AppDelegate.main.data
    private var scorer: BrowsingScorer? {
        page.browsingScorer
    }
    let shapeCache = PnSTargetsShapeCache()

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

    let throttledHaptic = throttle(delay: 0.1, action: {
        // bump trackpad haptic
        let performer = NSHapticFeedbackManager.defaultPerformer
        performer.perform(.alignment, performanceTime: .default)
    })

    /// Set activePointGroup with target. Updating the activePointGroup will update the UI directly.
    func point(_ target: Target, _ text: String, _ href: String) {
        guard activeShootGroup == nil else { return }
        guard !isTypingOnWebView else { return }

        if isAltKeyDown {
            if let group = activePointGroup,
               let pointTarget = group.targets.first,
               pointTarget.rect != target.rect {
                throttledHaptic()
            }
        }

        activePointGroup = ShootGroup("point-uuid", [target], text, href, shapeCache: shapeCache)

    }

    /// Set targets as activeShootGroup
    /// - Parameters:
    ///   - groupId: id of group
    ///   - targets: Set of targets to draw
    ///   - href: Url of frame targets are located in
    func pointShoot(_ groupId: String, _ target: Target, _ text: String, _ href: String) {
        guard !targetIsDismissed(groupId), !hasActiveSelection else { return }

        if targetIsCollected(groupId) {
            collect(groupId, [target], text, href)
            return
        }

        if (isAltKeyDown || activeShootGroup != nil), activePointGroup != nil {
            // if we have an existing group matching the id
            if activeShootGroup != nil, activeShootGroup?.id == groupId {
                activeShootGroup?.updateTargets(groupId, [target])
            } else if hasGraceRectAndMouseOverlap(target, href, mouseLocation),
                      !isLargeTargetArea(target),
                      !isTypingOnWebView,
                      activeSelectGroup == nil,
                      activeShootGroup == nil {

                activeShootGroup = ShootGroup(groupId, [target], text, href, shapeCache: shapeCache)
                if let group = self.activeShootGroup,
                   let sourceUrl = self.page.url {
                    let text = group.text
                    self.page.addTextToClusteringManager(text, url: sourceUrl)
                }
                throttledHaptic()
            } else {
                if !isAltKeyDown {
                    let tempGroup = ShootGroup(groupId, [], text, href, shapeCache: shapeCache)
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
    func select(_ groupId: String, _ targets: [Target], _ text: String, _ href: String) {
        guard !isTypingOnWebView, !targets.isEmpty else {
            return
        }
        // Check if the incomming group is already collected
        if targetIsCollected(groupId) {
            collect(groupId, targets, text, href)
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
            let shouldUpdatePath = isAltKeyDown || targets.count <= 1
            activeSelectGroup?.updateTargets(groupId, targets, updatePath: shouldUpdatePath)
            return
        } else if hasActiveSelection, activeSelectGroup == nil {
            // Create a new Selection group
            activeSelectGroup = ShootGroup(groupId, targets, text, href, shapeCache: shapeCache)
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
            activeSelectGroup = nil
            dismissedGroups.append(selectionGroup)
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
            collect(group.id, group.targets, group.text, group.href)
            return
        }
        guard !isTypingOnWebView else { return }
        var group = group
        group.updateSelectionPath()
        activeShootGroup = group

        if let sourceUrl = self.page.url {
            let text = group.text
            self.page.addTextToClusteringManager(text, url: sourceUrl)
        }
    }

    /// Set or update targets to collectedGroup
    /// - Parameters:
    ///   - groupId: id of group to update
    ///   - targets: Set of targets to draw
    ///   - href: Url of frame targets are located in
    func collect(_ groupId: String, _ targets: [Target], _ text: String, _ href: String) {
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
            let newGroup = ShootGroup(groupId, targets, text, href, shapeCache: shapeCache)
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
    func addShootToNote(targetNote: BeamNote, withNote noteText: String? = nil, group: ShootGroup, completion: @escaping () -> Void) {
        guard let sourceUrl = page.url else {
            fatalError("Could not find note to update with title \(targetNote.title)")
        }
        // Make group mutable
        var shootGroup = group
        // Convert html to BeamText
        let htmlNoteAdapter = HtmlNoteAdapter(sourceUrl, self.page.downloadManager, self.page.fileStorage)
        htmlNoteAdapter.convert(html: shootGroup.html(), completion: { [self] (beamElements: [BeamElement]) in
            // exit early when failing to collect correctly
            guard beamElements.count != 0 else {
                Logger.shared.logError("BE-007 FAIL", category: .general)
                self.showAlert(shootGroup, beamElements, "failed to collect html elements", completion: {
                    shootGroup.setConfirmation(.failure)
                    self.showShootConfirmation(group: shootGroup)
                    completion()
                })
                return
            }

            let elements = beamElements.map({ element -> BeamElement in
                element.query = self.page.originalQuery

                guard element.kind == .bullet else { return element }

                element.kind = .quote(1, sourceUrl.absoluteString, group.href)
                return element
            })
            // Update shootgroup information
            shootGroup.numberOfElements = elements.count
            shootGroup.setNoteInfo(NoteInfo(id: targetNote.id, title: targetNote.title))
            // Set Destination note to the current card
            // Update BrowsingScorer about note submission
            page.setDestinationNote(targetNote, rootElement: targetNote)
            scorer?.addTextSelection()
            // TODO: Convert BeamText to BeamElement of quote type
            // Adds urlId to current card source
            let urlId = LinkStore.getOrCreateIdFor(sourceUrl.absoluteString)
            targetNote.sources.add(urlId: urlId, noteId: targetNote.id, type: .user, sessionId: self.data.sessionId, activeSources: data.activeSources)
            // Updates frecency score of destination note
            self.data.noteFrecencyScorer.update(id: targetNote.id, value: 1.0, eventType: .notePointAndShoot, date: BeamDate.now, paramKey: .note30d0)
            self.data.noteFrecencyScorer.update(id: targetNote.id, value: 1.0, eventType: .notePointAndShoot, date: BeamDate.now, paramKey: .note30d1)
            // Add all quotes to source Note

            let addWithSourceBullet = shouldAddWithSourceBullet(elements)
            if let destinationElement = self.page.addToNote(allowSearchResult: true, inSourceBullet: addWithSourceBullet) {
                if let noteText = noteText, !noteText.isEmpty, let lastQuote = elements.last {
                    // Append NoteText last quote
                    let note = self.createNote(noteText)
                    lastQuote.addChild(note)
                }

                // Add to source Note
                if destinationElement.children.count == 1,
                   let onlyChild = destinationElement.children.first,
                   onlyChild.text.isEmpty, onlyChild.kind == .bullet {
                    destinationElement.removeChild(onlyChild)
                }
                elements.forEach({ quote in destinationElement.addChild(quote) })
                shootGroup.setConfirmation(.success)
                self.showShootConfirmation(group: shootGroup)
                completion()
            }
        })
    }

    /// Draws shoot confirmation
    /// - Parameter group: ShootGroup of targets to draw the confirmation UI
    private func showShootConfirmation(group: ShootGroup) {
        guard let confirmation = group.confirmation else {
            fatalError("ShootGroup confirmation enum should be set, instead recieved: \(group)")
        }
        var mutableGroup = group
        mutableGroup.setConfirmation(confirmation)
        self.collectedGroups.append(mutableGroup)
        self.activeShootGroup = nil
        shootConfirmationGroup = mutableGroup
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            self.shootConfirmationGroup = nil
        }
    }

    /// Clears all stored Point and Shoot session data
    func leavePage() {
        activePointGroup = nil
        activeSelectGroup = nil
        activeShootGroup = nil
        shapeCache.clear()
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

    //This variable could be migrated as a preference if we want. Setting to true gives the original PnS behavior
    var embedMediaInSourceBullet = false

    /// Decides if this set of elements should be inserted with a source bullet
    /// - Parameter elements: Array of BeamElement content
    /// - Returns: true if elements should be added under a source bullen
    private func shouldAddWithSourceBullet(_ elements: [BeamElement]) -> Bool {
        guard !embedMediaInSourceBullet,
              let first = elements.first,
                elements.count == 1 else { return true }

        // A single Image should be inserted without source bullet
        if first.kind.isMedia {
            return false
        }

        return true
    }
}
