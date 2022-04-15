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
class PointAndShoot: NSObject, WebPageRelated, ObservableObject {

    fileprivate func playShootSound() {
        guard PreferencesManager.isCollectSoundsEnabled else { return }
        SoundEffectPlayer.shared.playSound(.pointAndShootCollect)
    }

    fileprivate func playCollectSound() {
        guard PreferencesManager.isCollectSoundsEnabled else { return }
        SoundEffectPlayer.shared.playSound(.pointAndShootConfirm)
    }

    var data: BeamData = AppDelegate.main.data
    private var scorer: BrowsingScorer? {
        page?.browsingScorer
    }
    let shapeCache = PnSTargetsShapeCache()

    @Published var activePointGroup: ShootGroup?
    @Published var activeSelectGroup: ShootGroup?
    @Published var activeShootGroup: ShootGroup?
    @Published var collectedGroups: [ShootGroup] = []
    /// Don't append directly but go through the `dismissShootGroup` method
    @Published var dismissedGroups: [ShootGroup] = []
    @Published var shootConfirmationGroup: ShootGroup?
    @Published var isAltKeyDown: Bool = false
    @Published var hasActiveSelection: Bool = false
    @Published var isTypingOnWebView: Bool = false
    @Published var mouseLocation: NSPoint = NSPoint()
    @Published var hasCollectedFullPage: Bool = false

    private var isEnabled: Bool {
        guard let page = self.page else { return false }
        return !isTypingOnWebView && page.pointAndShootEnabled
    }

    weak var page: WebPage? {
        didSet {
            self.page?.webView.optionKeyToggle = { [weak self] key in
                guard let self = self else { return }
                self.refresh(self.mouseLocation, key)
            }
            self.page?.webView.mouseClickChange = { [weak self] (mousePos) in
                self?.handleMouseClick(mousePos)
            }
            self.page?.webView.mouseMoveTriggeredChange = { [weak self] (mousePos, modifier) in
                self?.refresh(mousePos, modifier)
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
        guard isEnabled else { return }
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

    let throttledHaptic = throttle(delay: 0.2, action: {
        // bump trackpad haptic
        let performer = NSHapticFeedbackManager.defaultPerformer
        performer.perform(.alignment, performanceTime: .default)
    })

    /// Set activePointGroup with target. Updating the activePointGroup will update the UI directly.
    func point(_ target: Target, _ text: String, _ href: String) {
        guard isEnabled else { return }
        guard activeShootGroup == nil else { return }

        if isAltKeyDown {
            if let group = activePointGroup,
               let pointTarget = group.targets.first,
               pointTarget.rect != target.rect {
                throttledHaptic()
            }
        }

        activePointGroup = ShootGroup(id: "point-uuid", targets: [target], text: text, href: href, shapeCache: shapeCache)

    }

    /// Set targets as activeShootGroup
    /// - Parameters:
    ///   - groupId: id of group
    ///   - targets: Set of targets to draw
    ///   - href: Url of frame targets are located in
    func pointShoot(_ groupId: String, _ target: Target, _ text: String, _ href: String) {
        guard isEnabled else { return }
        guard !targetIsDismissed(groupId), !hasActiveSelection else { return }

        if targetIsCollected(groupId) {
            collect(groupId, [target], text, href)
            return
        }

        // Dismiss group when we won't we creating or updating any ShootGroup
        guard (isAltKeyDown || activeShootGroup != nil), activePointGroup != nil else {
            dismissShootGroup(id: groupId, href: href)
            return
        }

        // If we have an existing group matching the id
        if activeShootGroup != nil, activeShootGroup?.id == groupId {
            activeShootGroup?.updateTargets(groupId, [target])
        } else if hasGraceRectAndMouseOverlap(target, href, mouseLocation),
                  !isLargeTargetArea(target),
                  !isTypingOnWebView,
                  activeSelectGroup == nil,
                  activeShootGroup == nil {

            activeShootGroup = ShootGroup(id: groupId, targets: [target], text: text, href: href, shapeCache: shapeCache)
            if let group = self.activeShootGroup,
               let sourceUrl = self.page?.url {
                let text = group.text
                self.page?.addTextToClusteringManager(text, url: sourceUrl)
            }
            playShootSound()
            throttledHaptic()
        } else {
            if !isAltKeyDown {
                dismissShootGroup(id: groupId, href: href)
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
        guard isEnabled, !targets.isEmpty else { return }
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
            activeSelectGroup = ShootGroup(id: groupId, targets: targets, text: text, href: href, shapeCache: shapeCache)
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
            dismissShootGroup(id: selectionGroup.id, href: selectionGroup.href)
        }
    }

    /// Sets selection group as activeShootGroup
    /// - Parameters:
    ///   - group: Group to be converted
    func selectShoot(_ group: ShootGroup) {
        guard isEnabled else { return }
        guard !targetIsDismissed(group.id) else {
            return
        }

        if targetIsCollected(group.id) {
            collect(group.id, group.targets, group.text, group.href)
            return
        }
        var group = group
        group.updateSelectionPath()
        activeShootGroup = group
        playShootSound()
        if let sourceUrl = self.page?.url {
            let text = group.text
            self.page?.addTextToClusteringManager(text, url: sourceUrl)
        }
    }

    /// Set or update targets to collectedGroup
    /// - Parameters:
    ///   - groupId: id of group to update
    ///   - targets: Set of targets to draw
    ///   - href: Url of frame targets are located in
    func collect(_ groupId: String, _ targets: [Target], _ text: String, _ href: String) {
        guard isEnabled else { return }
        guard targets.count > 0 else { return }

        // Keep shootConfirmationGroup position when scrolling
        if shootConfirmationGroup != nil {
            shootConfirmationGroup?.updateTargets(groupId, targets)
        }

        if let index = collectedGroups.firstIndex(where: {$0.id == groupId}) {
            var existingGroup = collectedGroups[index]
            existingGroup.updateTargets(groupId, targets)
            collectedGroups[index] = existingGroup
        } else {
            let newGroup = ShootGroup(id: groupId, targets: targets, text: text, href: href, shapeCache: shapeCache)
            collectedGroups.append(newGroup)
        }
    }

    /// Small Utility to create a BeamElement containing noteText
    /// - Parameter noteText: Text of note
    /// - Returns: BeamElement containing noteText without any styling
    fileprivate func createNote(_ noteText: String) -> BeamElement {
        let note = BeamElement(BeamText(text: noteText))
        note.query = self.page?.originalQuery
        return note
    }

    /// Adds the activeShootGroup to the journal. It will convert the html to beamtext,
    /// apply quote styling and download any target images.
    /// - Parameters:
    ///   - targetNote: The note the shootgroup should be added to
    ///   - group: ShootGroup to add
    ///   - withSourceBullet: If shoot should be inserted underneath a source bullet
    ///   - completion:
    ///   - noteText: optional text to add underneath the shoot quote
    func addShootToNote(targetNote: BeamNote, withNote noteText: String? = nil, group: ShootGroup, withSourceBullet: Bool = true, completion: @escaping () -> Void) {
        guard let page = self.page, let sourceUrl = page.url else {
            Logger.shared.logError("Expected webpage to be defined when adding shoot to note", category: .pointAndShoot)
            return
        }

        // Make group mutable
        var shootGroup = group
        // Convert html to BeamText
        let htmlNoteAdapter = HtmlNoteAdapter(sourceUrl, self.page?.downloadManager, page.fileStorage)
        htmlNoteAdapter.convert(html: shootGroup.html(), completion: { [weak self] (beamElements: [BeamElement]) in
            guard let self = self else { return }
            // exit early when failing to collect correctly
            guard beamElements.count != 0 else {
                self.showAlert(shootGroup, beamElements, "failed to collect html elements", completion: {
                    shootGroup.setConfirmation(.failure)
                    self.showShootConfirmation(group: shootGroup)
                    completion()
                })
                return
            }

            let elements = beamElements.map({ element -> BeamElement in
                element.query = page.originalQuery

                guard element.kind == .bullet else { return element }
                element.text.addAttributes([.source(SourceMetadata(origin: .remote(sourceUrl), title: page.title))], to: element.text.wholeRange)
                return element
            })
            // Update shootgroup information
            shootGroup.numberOfElements = elements.count
            shootGroup.setNoteInfo(NoteInfo(id: targetNote.id, title: targetNote.title))
            // Set Destination note to the current note
            page.setDestinationNote(targetNote, rootElement: targetNote)
            // Add all quotes to source Note
            let addWithSourceBullet = withSourceBullet ? self.shouldAddWithSourceBullet(elements) : withSourceBullet
            if let destinationElement = page.addToNote(allowSearchResult: true, inSourceBullet: addWithSourceBullet) {
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

                // Add sourceUrl to note sources
                self.setNoteSources(targetNote: targetNote, sourceUrl: sourceUrl)

                // Show confirmation UI
                shootGroup.setConfirmation(.success)
                self.showShootConfirmation(group: shootGroup)
                completion()
            }
        })
    }

    func shareShootToService(group: ShootGroup, service: ShareService) {
        guard let page = self.page, let sourceUrl = page.url else { return }
        Task { @MainActor in
            let htmlNoteAdapter = HtmlNoteAdapter(sourceUrl, page.downloadManager, page.fileStorage)
            let helper = ShareHelper(sourceUrl, htmlNoteAdapter: htmlNoteAdapter) { [weak self] url in
                let webView = self?.page?.createNewWindow(url, nil, windowFeatures: ShareWindowFeatures(for: service), setCurrent: true)
                webView?.load(URLRequest(url: url))
            }
            await helper.shareContent(group.html(), originURL: sourceUrl, service: service)
            if service != .copy {
                cancelShoot()
            }
        }
    }

    /// Draws shoot confirmation
    /// - Parameter group: ShootGroup of targets to draw the confirmation UI
    private func showShootConfirmation(group: ShootGroup) {
        guard let confirmation = group.confirmation else {
            fatalError("ShootGroup confirmation enum should be set, instead received: \(group)")
        }
        playCollectSound()
        var mutableGroup = group
        mutableGroup.setConfirmation(confirmation)
        self.collectedGroups.append(mutableGroup)
        self.activeShootGroup = nil
        self.shootConfirmationGroup = mutableGroup

        // If it's a fullpage collect ShootGroup, disable future
        // full page collects until the flag is restored
        if mutableGroup.fullPageCollect {
            self.hasCollectedFullPage = true
        }

        // Finish animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            self.shootConfirmationGroup = nil
        }
    }

    /// Add url to the note's sources
    /// - Parameters:
    ///   - targetNote
    ///   - sourceUrl
    private func setNoteSources(targetNote: BeamNote, sourceUrl: URL) {
        // Update BrowsingScorer about note submission
        scorer?.addTextSelection()
        // Adds urlId to current note source
        let urlId = LinkStore.getOrCreateIdFor(sourceUrl.absoluteString)
        targetNote.sources.add(
            urlId: urlId,
            noteId: targetNote.id,
            type: .user,
            sessionId: self.data.sessionId,
            activeSources: data.activeSources
        )
        // Updates frecency score of destination note
        self.data.noteFrecencyScorer.update(
            id: targetNote.id,
            value: 1.0,
            eventType: .notePointAndShoot,
            date: BeamDate.now,
            paramKey: .note30d0
        )
        self.data.noteFrecencyScorer.update(
            id: targetNote.id,
            value: 1.0,
            eventType: .notePointAndShoot,
            date: BeamDate.now,
            paramKey: .note30d1
        )
    }

    /// Clears all stored Point and Shoot session data
    func leavePage() {
        activePointGroup = nil
        activeSelectGroup = nil
        activeShootGroup = nil
        shapeCache.clear()
        collectedGroups.removeAll()
        dismissedGroups.forEach { group in
            dismissShootGroup(id: group.id, href: group.href)
        }
        dismissedGroups.removeAll()
        shootConfirmationGroup = nil
        isAltKeyDown = false
        hasActiveSelection = false
        hasCollectedFullPage = false
    }

    func cancelShoot() {
        if let group = activeShootGroup {
            dismissShootGroup(id: group.id, href: group.href)
            activeShootGroup = nil
        }
        if let group = activeSelectGroup {
            dismissShootGroup(id: group.id, href: group.href)
            activeSelectGroup = nil
        }
    }

    /// Stop JS from sending updated bounds of target element
    ///
    /// Calling this is a performance improvement for the main window
    /// frame context only, we can't rely this gets properly executed within iframes.
    /// - Parameter id: ID of target to remove
    func removeTarget(_ id: String) {
        self.page?.executeJS("removeTarget(\"\(id)\")", objectName: "PointAndShoot")
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

        // If the element is a external link of a single embeddable url and
        // the convertLinksToEmbed preference is disabled. The link element should
        // be inserted without source bullet.
        for link in first.outLinks {
            if let url = URL(string: link) {
                let canEmbed = EmbedContentBuilder().canBuildEmbed(for: url)
                let disabledConvertingLinksToEmbed = HtmlVisitor.allowConvertToEmbed == false
                if canEmbed && disabledConvertingLinksToEmbed {
                    // If the element text is the same as the url target
                    // update the set the page title to the element text
                    if first.text.text == link,
                       let pageTitle = self.page?.title {
                        var linkWithPageTitle = BeamText(text: pageTitle)
                        linkWithPageTitle.addAttributes([.link(link)], to: linkWithPageTitle.wholeRange)
                        first.text = linkWithPageTitle
                    }
                    return false
                }
            }
        }

        // A single link matching the source bullet link should be inserted without source bullet
        guard let pageUrl = self.page?.url?.absoluteString else {
            Logger.shared.logDebug("Could not find page url while checking text links", category: .pointAndShoot)
            return true
        }
        guard let pageTitle = self.page?.title else {
            Logger.shared.logDebug("Could not find page title while checking text links", category: .pointAndShoot)
            return true
        }
        for link in first.text.links where (link == pageUrl) || (first.text.text == pageTitle) {
            return false
        }

        return true
    }
}
